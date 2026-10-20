//! Exception Entry Metadata

const vectors = @import("common").constants.interrupts.vectors;

pub const ERROR_CODE_VECTORS = [_]u8{ 8, 10, 11, 12, 13, 14, 17, 21, 29, 30 };
pub const HAS_ERROR_CODE = blk: {
    var table = [_]bool{false} ** vectors.EXCEPTION_COUNT;
    for (ERROR_CODE_VECTORS) |vector| {
        table[vector] = true;
    }
    break :blk table;
};
