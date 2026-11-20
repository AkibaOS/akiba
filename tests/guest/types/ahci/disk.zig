//! Attached Q35 Diagnostic Disk And Owned DMA Page

const sizes = @import("common").constants.memory.sizes;

pub const Disk = struct {
    Port: u64,
    Physical: u64,
    Page: *[sizes.PAGE_SIZE]u8,
    Sectors: u64,
};
