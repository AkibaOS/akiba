//! Allocated AFS Unit Buffer

pub const AllocatedBuffer = struct {
    Buffer: [*]u8,
    Size: u64,
};
