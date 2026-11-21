//! Display Entry Symbol And Stack Shim

pub const ENTRY = ".extern display_main\ncallq display_main\nud2";
pub const SECTION = ".text.display.entry";
