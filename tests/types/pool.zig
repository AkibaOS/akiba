//! Stable Storage Regression Values

const inputs = @import("tests").constants.pool;

pub const Value = struct {
    Bytes: [inputs.VALUE_BYTES]u8 align(inputs.VALUE_ALIGNMENT),
    Index: usize,
};

pub const Page = struct {
    Bytes: [inputs.PAGE_VALUE_BYTES]u8 align(inputs.VALUE_ALIGNMENT),
    Index: usize,
};

pub const Oversized = struct {
    Bytes: [inputs.OVERSIZED_BYTES]u8,
};

pub const Overaligned = struct {
    Byte: u8 align(inputs.OVER_ALIGNMENT),
};
