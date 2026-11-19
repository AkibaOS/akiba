//! Resource Lifetime Bound To A Delivered Call

pub const Lease = struct {
    Context: *anyopaque,
    Revoke: *const fn (*anyopaque) void,
};
