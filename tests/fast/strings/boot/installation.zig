//! Independent Installed Bundle Locations And Invalid Identities

pub const DRIVER = "keyboard.driver";
pub const BUNDLE = "keyboard.akiba";
pub const MANIFEST = "system/drivers/keyboard.driver/bundle.world";
pub const BINARY = "system/binaries/keyboard.akiba/binary";
pub const USER = "binaries/keyboard.akiba/binary";
pub const PULSE = "system/akiba/pulse.init";
pub const IDENTITY = "keyboard";
pub const VALID = [_][]const u8{ "keyboard", "a1", "request-probe", "com10", "lpt0" };
pub const INVALID = [_][]const u8{ "", ".", "..", "keyboard.driver", "../keyboard", "dir/keyboard", "dir\\keyboard", "CON", "con", "prn", "aux", "nul", "com1", "com9", "lpt1", "lpt9", "1key", "key-", "key--next", "key_name", "键盘", "key\x00board" };
