//! Hikari EFI Block I/O Protocol

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const BlockIoProtocol = extern struct {
    Revision: u64,
    Media: *types.block.BlockIoMedia,

    Reset: *const fn (
        self: *BlockIoProtocol,
        extended_verification: bool,
    ) callconv(convention) types.base.Status,

    ReadBlocks: *const fn (
        self: *BlockIoProtocol,
        media_id: u32,
        lba: types.base.LBA,
        buffer_size: usize,
        buffer: [*]u8,
    ) callconv(convention) types.base.Status,

    WriteBlocks: *const fn (
        self: *BlockIoProtocol,
        media_id: u32,
        lba: types.base.LBA,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(convention) types.base.Status,

    FlushBlocks: *const fn (
        self: *BlockIoProtocol,
    ) callconv(convention) types.base.Status,
};
