//! Hikari EFI Disk I/O Protocol

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");

pub const DiskIoProtocol = extern struct {
    revision: u64,

    read_disk: *const fn (
        self: *DiskIoProtocol,
        media_id: u32,
        offset: u64,
        buffer_size: usize,
        buffer: [*]u8,
    ) callconv(efi.akiba) types.Status,

    write_disk: *const fn (
        self: *DiskIoProtocol,
        media_id: u32,
        offset: u64,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(efi.akiba) types.Status,
};

pub const disk_io_protocol_revision: u64 = 0x00010000;
