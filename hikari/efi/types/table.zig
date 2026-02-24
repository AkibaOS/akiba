//! Hikari EFI Table Types

const base = @import("base.zig");

pub const TableHeader = extern struct {
    signature: u64,
    revision: u32,
    header_size: u32,
    crc32: u32,
    reserved: u32,
};

pub const ConfigurationTableEntry = extern struct {
    vendor_guid: base.Guid,
    vendor_table: *anyopaque,
};
