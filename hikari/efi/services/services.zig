//! Hikari EFI Services

pub const boot = @import("boot.zig");
pub const runtime = @import("runtime.zig");
pub const system = @import("system.zig");

pub const BootServices = boot.BootServices;
pub const RuntimeServices = runtime.RuntimeServices;
pub const SystemTable = system.SystemTable;
