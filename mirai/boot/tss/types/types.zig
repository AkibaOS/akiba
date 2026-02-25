//! TSS Types

pub const tss = @import("tss.zig");
pub const core_tss = @import("core_tss.zig");

pub const Tss = tss.Tss;
pub const CoreTss = core_tss.CoreTss;
pub const IstStack = core_tss.CoreTss.IstStack;
