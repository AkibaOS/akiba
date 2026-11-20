//! Bounded Read Only Native Sector Source

pub const Source = struct {
    Context: *anyopaque,
    Read: *const fn (*anyopaque, u64, []u8) anyerror!void,
    BlockBytes: u32,
    LastLBA: u64,
};
