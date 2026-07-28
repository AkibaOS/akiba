//! Hikari EFI Disk I/O Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;

const convention = constants.convention.CALLING_CONVENTION;

pub const DiskIoProtocol = extern struct {
    Revision: u64,

    ReadDisk: *const fn (
        self: *DiskIoProtocol,
        media_id: u32,
        offset: u64,
        buffer_size: usize,
        buffer: [*]u8,
    ) callconv(convention) types.base.Status,

    WriteDisk: *const fn (
        self: *DiskIoProtocol,
        media_id: u32,
        offset: u64,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(convention) types.base.Status,
};
