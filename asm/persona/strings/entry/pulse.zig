//! Pulse Entry Symbol And Stack Shim

pub const ENTRY = ".extern pulse_main\ncallq pulse_main\nud2";
pub const SECTION = ".text.pulse.entry";
