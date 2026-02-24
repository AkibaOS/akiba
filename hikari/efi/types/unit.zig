//! Hikari EFI Unit Types

const base = @import("base.zig");
const time = @import("time.zig");

pub const UnitInfo = extern struct {
    size: u64,
    unit_size: u64,
    physical_size: u64,
    create_time: time.Time,
    last_access_time: time.Time,
    modification_time: time.Time,
    attribute: u64,
    unit_name: [256]base.Char16,
};

pub const UnitSystemInfo = extern struct {
    size: u64,
    read_only: bool,
    volume_size: u64,
    free_space: u64,
    block_size: u32,
    volume_label: [256]base.Char16,
};
