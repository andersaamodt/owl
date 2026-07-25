pub mod cli;
pub mod envcfg;

pub mod daemon {
    pub mod service;
    pub mod watch;
}

pub mod model {
    pub mod address;
    pub mod filename;
    pub mod message;
    pub mod rules;
    pub mod settings;
}

pub mod fsops {
    pub mod attach;
    pub mod io_atom;
    pub mod layout;
}

pub mod pipeline {
    pub mod inbound;
    pub mod outbox;
    pub mod reconcile;
    pub mod render;
    pub mod smtp_in;
}

pub mod ruleset {
    pub mod eval;
    pub mod loader;
}

pub mod util {
    pub mod dkim;
    pub mod idna;
    pub mod logging;
    pub mod regex;
    pub mod size;
    pub mod time;
    pub mod ulid;
}

pub mod ops {
    pub mod install;
}

pub use envcfg::EnvConfig;
