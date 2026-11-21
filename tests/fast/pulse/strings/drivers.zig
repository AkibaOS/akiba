//! Installed Driver World Fixtures

pub const KEYBOARD = "driver version=1 abi=1 protocol=1 { match \"keyboard\"; }\n";
pub const SURFACE = "driver version=1 abi=1 protocol=1 { match \"framebuffer\" location=0; }\n";
pub const OTHER_PORT = "driver version=1 abi=1 protocol=1 { match \"keyboard\" location=2; }\n";
pub const WRONG_ABI = "driver version=1 abi=2 protocol=1 { match \"keyboard\"; }\n";
pub const MISSING_VERSION = "driver abi=1 protocol=1 { match \"keyboard\"; }\n";
pub const DUPLICATE_MATCH = "driver version=1 abi=1 protocol=1 { match \"keyboard\"; match \"framebuffer\"; }\n";
pub const BUILTIN = "keyboard";
pub const FOREIGN = "alternate";
pub const WRONG = "wrong";
