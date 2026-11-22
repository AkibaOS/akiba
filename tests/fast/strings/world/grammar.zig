//! Independent Shared World Grammar Fixtures

pub const MANIFEST = "\u{feff}(metadata)bundle keyboard enabled=false enabled = true count=0x10 disabled=null title=#\"two words\"# { /- hidden; provides keyboard version=1; }\n";
pub const EXTRA_ARGUMENT = "bundle version=1 keyboard\n";
pub const HASH_KEYWORD = "bundle enabled=#true\n";
pub const UNCLOSED = "bundle keyboard { provides keyboard version=1\n";
pub const BUNDLE = "bundle";
pub const KEYBOARD = "keyboard";
pub const METADATA = "metadata";
pub const TITLE = "two words";
pub const ENABLED = "enabled";
pub const COUNT = "count";
pub const DISABLED = "disabled";
pub const TITLE_KEY = "title";
pub const MISSING = "missing";
