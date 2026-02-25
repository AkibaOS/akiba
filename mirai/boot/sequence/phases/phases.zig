//! Boot Phases

pub const cpu = @import("cpu.zig");
pub const memory = @import("memory.zig");

pub const execute_cpu = cpu.execute;
pub const execute_memory = memory.execute;
