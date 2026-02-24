//! Hikari EFI Block I/O Types

const base = @import("base.zig");

pub const BlockIoMedia = extern struct {
    media_id: u32,
    removable_media: bool,
    media_present: bool,
    logical_partition: bool,
    read_only: bool,
    write_caching: bool,
    block_size: u32,
    io_align: u32,
    last_block: base.Lba,
    lowest_aligned_lba: base.Lba,
    logical_blocks_per_physical_block: u32,
    optimal_transfer_length_granularity: u32,
};
