//! Kernel Owned AHCI Command Slot

const sizes = @import("common").constants.memory.sizes;

pub const Slot = struct {
    Port: u64,
    Physical: u64,
    Page: *[sizes.PAGE_SIZE]u8,
};

pub const Use = *const fn (*anyopaque, Slot) anyerror!bool;
