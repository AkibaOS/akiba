//! Elapsed Rollback Animation State

pub const Clock = struct {
    Last: u32,
    Remainder: u32 = 0,
    Frame: usize = 0,
};
