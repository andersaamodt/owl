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
}
