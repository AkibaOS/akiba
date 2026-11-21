//! System Binary Storage Stack Names

const install = @import("shared").device.strings.install;

pub const SYSTEM_BINARIES = [_][]const u8{ install.SYSTEM, "binaries" };
pub const SYSTEM_DRIVERS = install.STACKS;
