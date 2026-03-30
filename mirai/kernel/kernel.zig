//! Kernel Module

pub const entry = @import("entry.zig");
pub const boot = @import("boot.zig");

pub const main = entry.main;
pub const BootParams = entry.BootParams;
