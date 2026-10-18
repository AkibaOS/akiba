//! Hikari EFI Aligned Buffer Types

pub const AlignedBuffer = struct {
    Allocation: [*]align(8) u8,
    Data: [*]align(8) u8,
    Size: usize,
};
