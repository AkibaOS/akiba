//! Hikari EFI Block I/O Protocol

const types = @import("../types/types.zig");
const block = @import("../types/block.zig");

pub const BlockIoProtocol = extern struct {
    revision: u64,
    media: *block.BlockIoMedia,

    reset: *const fn (
        self: *BlockIoProtocol,
        extended_verification: bool,
    ) callconv(.C) types.Status,

    read_blocks: *const fn (
        self: *BlockIoProtocol,
        media_id: u32,
        lba: types.Lba,
        buffer_size: usize,
        buffer: [*]u8,
    ) callconv(.C) types.Status,

    write_blocks: *const fn (
        self: *BlockIoProtocol,
        media_id: u32,
        lba: types.Lba,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(.C) types.Status,

    flush_blocks: *const fn (
        self: *BlockIoProtocol,
    ) callconv(.C) types.Status,
};

pub const block_io_protocol_revision1: u64 = 0x00010000;
pub const block_io_protocol_revision2: u64 = 0x00020001;
pub const block_io_protocol_revision3: u64 = 0x0002001F;
