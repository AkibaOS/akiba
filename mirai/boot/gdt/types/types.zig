//! GDT Types

pub const entry = @import("entry.zig");
pub const tss_descriptor = @import("tss_descriptor.zig");
pub const gdtr = @import("gdtr.zig");
pub const table = @import("table.zig");

pub const Entry = entry.Entry;
pub const TssDescriptor = tss_descriptor.TssDescriptor;
pub const Gdtr = gdtr.Gdtr;
pub const Table = table.Table;
