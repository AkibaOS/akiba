//! Allocated FAT32 Unit Buffer

pub const AllocatedBuffer = struct {
    Buffer: [*]u8,
    Size: u32,
};
