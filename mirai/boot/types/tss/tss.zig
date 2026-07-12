//! TSS Types

pub const structure = @import("structure.zig");
pub const core_tss = @import("core.zig");

pub const Tss = structure.Tss;
pub const CoreTss = core_tss.CoreTss;
pub const IstStack = core_tss.CoreTss.IstStack;
