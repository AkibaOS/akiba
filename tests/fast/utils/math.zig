//! Integer Math Regression Checks

const std = @import("std");

const constants = @import("tests").constants.utils;
const integer = @import("utils").math.integer;

pub fn ceilingDivisionBoundaries() !void {
    try std.testing.expectEqual(@as(u64, 0), integer.divideCeil(@as(u64, 0), 1));
    try std.testing.expectEqual(@as(u64, 0), integer.divideCeil(@as(u64, 0), 4096));
    try std.testing.expectEqual(@as(u64, 1), integer.divideCeil(@as(u64, 1), 4096));
    try std.testing.expectEqual(@as(u64, 1), integer.divideCeil(@as(u64, 4095), 4096));
    try std.testing.expectEqual(@as(u64, 1), integer.divideCeil(@as(u64, 4096), 4096));
    try std.testing.expectEqual(@as(u64, 2), integer.divideCeil(@as(u64, 4097), 4096));
    try std.testing.expectEqual(@as(u64, 3), integer.divideCeil(@as(u64, 7), 3));
    try std.testing.expectEqual(@as(u64, 2), integer.divideCeil(@as(u64, 6), 3));
}

pub fn ceilingDivisionLimits() !void {
    try std.testing.expectEqual(@as(u64, 1), integer.divideCeil(@as(u64, 1), 0xffffffffffffffff));
    try std.testing.expectEqual(@as(u64, 1), integer.divideCeil(@as(u64, 0xffffffffffffffff), 0xffffffffffffffff));
    try std.testing.expectEqual(@as(u64, 0x8000000000000000), integer.divideCeil(@as(u64, 0xffffffffffffffff), 2));
    try std.testing.expectEqual(@as(u64, 0xffffffffffffffff), integer.divideCeil(@as(u64, 0xffffffffffffffff), 1));
    try std.testing.expectEqual(@as(u32, 1431655765), integer.divideCeil(@as(u32, 0xffffffff), 3));
    try std.testing.expectEqual(@as(u8, 128), integer.divideCeil(@as(u8, 255), 2));
}

pub fn alignmentBoundaries() !void {
    try std.testing.expectEqual(@as(u64, 0), integer.alignUp(@as(u64, 0), 4096));
    try std.testing.expectEqual(@as(u64, 0), integer.alignDown(@as(u64, 0), 4096));
    try std.testing.expectEqual(@as(u64, 4096), integer.alignUp(@as(u64, 1), 4096));
    try std.testing.expectEqual(@as(u64, 0), integer.alignDown(@as(u64, 4095), 4096));
    try std.testing.expectEqual(@as(u64, 4096), integer.alignUp(@as(u64, 4095), 4096));
    try std.testing.expectEqual(@as(u64, 4096), integer.alignUp(@as(u64, 4096), 4096));
    try std.testing.expectEqual(@as(u64, 4096), integer.alignDown(@as(u64, 4096), 4096));
    try std.testing.expectEqual(@as(u64, 8192), integer.alignUp(@as(u64, 4097), 4096));
    try std.testing.expectEqual(@as(u64, 4096), integer.alignDown(@as(u64, 4097), 4096));
}

pub fn alignmentLimits() !void {
    try std.testing.expectEqual(@as(u64, 0xfffffffffffff000), integer.alignUp(@as(u64, 0xffffffffffffefff), 4096));
    try std.testing.expectEqual(@as(u64, 0xfffffffffffff000), integer.alignDown(@as(u64, 0xffffffffffffffff), 4096));
    try std.testing.expectEqual(@as(u64, 0xffffffffffffffff), integer.alignDown(@as(u64, 0xffffffffffffffff), 1));
    try std.testing.expectEqual(@as(u64, 0x8000000000000000), integer.alignUp(@as(u64, 1), 0x8000000000000000));
    try std.testing.expectEqual(@as(u64, 0x8000000000000000), integer.alignDown(@as(u64, 0xffffffffffffffff), 0x8000000000000000));
}

pub fn alignmentWidths() !void {
    try std.testing.expectEqual(@as(u8, 248), integer.alignUp(@as(u8, 247), 8));
    try std.testing.expectEqual(@as(u8, 248), integer.alignDown(@as(u8, 255), 8));
    try std.testing.expectEqual(@as(u16, 65520), integer.alignUp(@as(u16, 65519), 16));
    try std.testing.expectEqual(@as(u16, 65520), integer.alignDown(@as(u16, 65535), 16));
    try std.testing.expectEqual(@as(u32, 77), integer.alignUp(@as(u32, 77), 1));
    try std.testing.expectEqual(@as(u32, 77), integer.alignDown(@as(u32, 77), 1));
}

pub fn squareRootBoundaries() !void {
    for (constants.SQUARE_ROOT_CASES) |case| {
        try std.testing.expectEqual(case.Root, integer.squareRoot(case.Value));
    }
}
