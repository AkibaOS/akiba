//! Bitmap Module

pub const operations = @import("operations.zig");

pub const set_bit = operations.set_bit;
pub const clear_bit = operations.clear_bit;
pub const test_bit = operations.test_bit;
pub const set_range = operations.set_range;
pub const clear_range = operations.clear_range;
pub const find_first_clear = operations.find_first_clear;
pub const find_contiguous_clear = operations.find_contiguous_clear;
pub const count_clear_bits = operations.count_clear_bits;
