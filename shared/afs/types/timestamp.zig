//! AFS Timestamp Type

pub const Timestamp = extern struct {
    Seconds: i64 = 0,
    Nanoseconds: u32 = 0,
    Reserved: u32 = 0,
};
