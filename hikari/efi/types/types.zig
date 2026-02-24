//! Hikari EFI Types

pub const base = @import("base.zig");
pub const memory = @import("memory.zig");
pub const table = @import("table.zig");
pub const time = @import("time.zig");
pub const input = @import("input.zig");
pub const graphics = @import("graphics.zig");
pub const unit = @import("unit.zig");
pub const block = @import("block.zig");
pub const reset = @import("reset.zig");

pub const Handle = base.Handle;
pub const Event = base.Event;
pub const Status = base.Status;
pub const PhysicalAddress = base.PhysicalAddress;
pub const VirtualAddress = base.VirtualAddress;
pub const Char16 = base.Char16;
pub const Guid = base.Guid;
pub const Lba = base.Lba;

pub const is_error = base.is_error;
pub const is_success = base.is_success;
