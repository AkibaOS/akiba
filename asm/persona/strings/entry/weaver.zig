//! Weaver Entry Symbol And Stack Shim

pub const ENTRY = ".extern weaver_main\ncallq weaver_main\nud2";
pub const SECTION = ".text.weaver.entry";
