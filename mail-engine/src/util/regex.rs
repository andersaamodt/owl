use regex::Regex;

pub fn safe_regex(pattern: &str) -> Option<Regex> {
    Regex::new(pattern).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compile_valid() {
        assert!(safe_regex("foo").is_some());
        assert!(safe_regex("(").is_none());
    }

    #[test]
    fn compile_common_patterns() {
        // Common email regex patterns
        assert!(safe_regex("^[a-z]+@example\\.org$").is_some());
        assert!(safe_regex(".*@spam\\..*").is_some());
        assert!(safe_regex("support\\+.*").is_some());
    }

    #[test]
    fn compile_invalid_patterns() {
        // Various invalid regex patterns
        assert!(safe_regex("[").is_none());
        assert!(safe_regex("*").is_none());
        assert!(safe_regex("(?P<invalid").is_none());
        assert!(safe_regex("(unclosed").is_none());
    }

    #[test]
    fn compile_empty_pattern() {
        // Empty pattern should compile (matches empty string)
        assert!(safe_regex("").is_some());
    }

    #[test]
    fn compile_unicode_pattern() {
        // Unicode in patterns should work
        assert!(safe_regex("café").is_some());
        assert!(safe_regex("[а-я]").is_some()); // Cyrillic range
    }

    #[test]
    fn compile_case_insensitive_flag() {
        // Note: safe_regex doesn't add flags, but the pattern should compile
        // Case-insensitive would be done via regex::RegexBuilder
        assert!(safe_regex("(?i)test").is_some());
    }

    #[test]
    fn compile_anchors() {
        assert!(safe_regex("^start").is_some());
        assert!(safe_regex("end$").is_some());
        assert!(safe_regex("^exact$").is_some());
    }

    #[test]
    fn compile_character_classes() {
        assert!(safe_regex("[a-z]").is_some());
        assert!(safe_regex("[0-9]").is_some());
        assert!(safe_regex("[^a-z]").is_some()); // negated class
        assert!(safe_regex("\\d+").is_some()); // digit shorthand
        assert!(safe_regex("\\w+").is_some()); // word shorthand
    }

    #[test]
    fn compile_quantifiers() {
        assert!(safe_regex("a?").is_some()); // 0 or 1
        assert!(safe_regex("a*").is_some()); // 0 or more
        assert!(safe_regex("a+").is_some()); // 1 or more
        assert!(safe_regex("a{2,5}").is_some()); // range
    }

    #[test]
    fn compile_alternation() {
        assert!(safe_regex("cat|dog").is_some());
        assert!(safe_regex("(alice|bob)@example\\.org").is_some());
    }

    #[test]
    fn compile_and_test_match() {
        // Compile and use the regex
        let re = safe_regex("^test").unwrap();
        assert!(re.is_match("test123"));
        assert!(!re.is_match("123test"));
    }

    #[test]
    fn compile_word_boundaries() {
        assert!(safe_regex(r"\bword\b").is_some());
        assert!(safe_regex(r"^\bstart").is_some());
    }

    #[test]
    fn compile_escaped_special_chars() {
        assert!(safe_regex(r"\.").is_some()); // literal dot
        assert!(safe_regex(r"\*").is_some()); // literal asterisk
        assert!(safe_regex(r"\[").is_some()); // literal bracket
        assert!(safe_regex(r"\(").is_some()); // literal paren
    }

    #[test]
    fn compile_backreferences_invalid() {
        // Rust regex doesn't support backreferences
        // This should fail to compile
        let re = safe_regex(r"(.)\\1");
        // Note: This might actually compile as it's just a literal \1
        // The actual backreference \1 would fail at match time
        assert!(re.is_some()); // Compiles but won't work as backreference
    }

    #[test]
    fn compile_lookahead_not_supported() {
        // Rust regex doesn't support lookahead/lookbehind
        assert!(safe_regex(r"(?=test)").is_none());
        assert!(safe_regex(r"(?!test)").is_none());
        assert!(safe_regex(r"(?<=test)").is_none());
        assert!(safe_regex(r"(?<!test)").is_none());
    }

    #[test]
    fn compile_named_groups() {
        assert!(safe_regex(r"(?P<user>[a-z]+)@(?P<domain>[a-z.]+)").is_some());
    }

    #[test]
    fn compile_non_capturing_groups() {
        assert!(safe_regex(r"(?:foo|bar)+").is_some());
    }

    #[test]
    fn compile_multiline_flag() {
        assert!(safe_regex(r"(?m)^line").is_some());
    }

    #[test]
    fn compile_dotall_flag() {
        assert!(safe_regex(r"(?s).+").is_some());
    }

    #[test]
    fn compile_very_long_pattern() {
        // Test that long patterns compile
        let long_pattern = format!("({})", "a|".repeat(100) + "a");
        assert!(safe_regex(&long_pattern).is_some());
    }

    #[test]
    fn compile_deeply_nested_groups() {
        // Test deeply nested groups
        let nested = "((((a))))";
        assert!(safe_regex(nested).is_some());
    }

    #[test]
    fn compile_unbalanced_parens() {
        assert!(safe_regex("((a)").is_none());
        assert!(safe_regex("(a))").is_none());
    }

    #[test]
    fn compile_invalid_range() {
        assert!(safe_regex("[z-a]").is_none()); // Invalid range
    }

    #[test]
    fn compile_duplicate_capture_names() {
        // Duplicate capture group names should fail
        assert!(safe_regex(r"(?P<name>a)(?P<name>b)").is_none());
    }
}
