//! OS information utilities

pub const cpu = @import("cpu.zig");
pub const disk = @import("disk.zig");
pub const mem = @import("memory.zig");
pub const up = @import("uptime.zig");
pub const types = @import("types.zig");

pub const cpuinfo = cpu.info;
pub const meminfo = mem.info;
pub const diskinfo = disk.info;
pub const uptime = up.get;

pub const MemInfo = types.MemInfo;
pub const DiskInfo = types.DiskInfo;
