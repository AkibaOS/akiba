//! Fixed IRQ Buffer And Ownership For Translated PS/2 Bytes

const memory = @import("common").constants.memory.sizes;

pub const Stream = struct {
    Driver: u64 = 0,
    Bytes: [memory.PAGE_SIZE]u8 = undefined,
    Head: usize = 0,
    Count: usize = 0,
    Lost: bool = false,
};
