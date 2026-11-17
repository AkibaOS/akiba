//! Ordered Index Regression Inputs

pub const LARGE_COUNT: usize = 2049;
pub const PERMUTATION_FACTOR: usize = 1021;
pub const VALIDATION_INTERVAL: usize = 31;
pub const MAX_TEST_DEPTH: usize = 64;
pub const ROTATIONS = [_][3]u128{
    .{ 3, 2, 1 },
    .{ 1, 2, 3 },
    .{ 3, 1, 2 },
    .{ 1, 3, 2 },
};
pub const REMOVE_KEYS = [_]u128{ 4, 2, 6, 1, 3, 5, 7, 8 };
pub const REMOVAL_ORDER = [_]usize{ 3, 6, 2, 0, 1, 7, 4, 5 };
pub const WIDE_KEYS = [_]u128{
    0,
    1,
    0xffffffffffffffff,
    0x10000000000000000,
    0x80000000000000000000000000000000,
    0xffffffffffffffffffffffffffffffff,
};
