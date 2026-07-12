//! AFS Timestamp Type

pub const Timestamp = extern struct {
    seconds: i64 = 0,
    nanoseconds: u32 = 0,
    reserved: u32 = 0,
};
