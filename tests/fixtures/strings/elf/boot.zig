//! Diagnostic Disk Only Persona ELF Unit Names

pub const ROOT = "tests";
pub const STACK = "bootstrap";
pub const UNIT = "fixture.elf";
pub const MISSING = "missing.elf";
pub const PARENTS = [_][]const u8{ ROOT, STACK };
pub const PATH = ROOT ++ "/" ++ STACK ++ "/" ++ UNIT;
