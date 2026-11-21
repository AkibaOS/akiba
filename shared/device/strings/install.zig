//! Installed Device Catalog Locations

pub const SYSTEM = "system";
pub const DRIVERS = "drivers";
pub const STACKS = [_][]const u8{ SYSTEM, DRIVERS };
pub const DIRECTORY = SYSTEM ++ "/" ++ DRIVERS;
pub const OVERRIDES = SYSTEM ++ "/world/drivers.world";
pub const COMPANION = ".world";
pub const UNIT_FORMAT = DIRECTORY ++ "/{s}";
