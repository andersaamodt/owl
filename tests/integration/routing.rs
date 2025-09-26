use owl::{
    envcfg::EnvConfig,
    model::{address::Address, rules::RuleSet},
    ruleset::{eval::Route, loader::LoadedRules},
    pipeline::inbound::determine_route,
};

#[test]
fn routing_precedence() {
    let sender = Address::parse("eve@malicious.example", false).unwrap();
    let mut loaded = LoadedRules::default();
    loaded.banned.rules = RuleSet::from_str("@malicious.example").unwrap();
    let route = determine_route(&sender, &loaded, &EnvConfig::default()).unwrap();
    assert_eq!(route, Route::Banned);
}

#[test]
fn list_settings_change_route() {
    let sender = Address::parse("ally@example.org", false).unwrap();
    let mut loaded = LoadedRules::default();
    loaded.spam.rules = RuleSet::from_str("@example.org").unwrap();
    loaded.spam.settings.list_status = "accepted".into();
    let route = determine_route(&sender, &loaded, &EnvConfig::default()).unwrap();
    assert_eq!(route, Route::Accepted);
}
