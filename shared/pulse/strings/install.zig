//! Canonical Core Pulse Unit Location

pub const SYSTEM = "system";
pub const AKIBA = "akiba";
pub const UNIT = "pulse";
pub const STACKS = [_][]const u8{ SYSTEM, AKIBA };
pub const PATH = SYSTEM ++ "/" ++ AKIBA ++ "/" ++ UNIT;
