//! Finite Real Backing For Persona Arena Tests

const sizes = @import("common").constants.memory.sizes;

pub const Backing = struct {
    Bytes: [2 * sizes.PAGE_SIZE]u8 align(sizes.PAGE_SIZE) = undefined,
    Mapped: usize = 0,
};
