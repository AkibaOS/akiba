//! Keyboard Entry Symbol And Stack Shim

pub const ENTRY = ".extern keyboard_main\ncallq keyboard_main\nud2";
pub const SECTION = ".text.keyboard.entry";
