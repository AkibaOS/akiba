//! Ordered Index Validation Result

pub const Validation = struct {
    Count: usize = 0,
    Height: u8 = 0,
    Minimum: ?u128 = null,
    Maximum: ?u128 = null,
};
