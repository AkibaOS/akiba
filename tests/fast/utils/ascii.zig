//! ASCII Regression Checks

const std = @import("std");

const ascii = @import("utils").text.ascii;
const strings = @import("tests").fast.strings.utils.vectors;

pub fn uppercaseBoundaries() !void {
    const input = [_]u8{ 0x00, 0x40, 0x41, 0x5a, 0x5b, 0x60, 0x61, 0x7a, 0x7b, 0x7f, 0x80, 0xff };
    const expected = [_]u8{ 0x00, 0x40, 0x41, 0x5a, 0x5b, 0x60, 0x41, 0x5a, 0x7b, 0x7f, 0x80, 0xff };

    for (input, expected) |character, uppercase| {
        try std.testing.expectEqual(uppercase, ascii.toUpper(character));
    }
}

pub fn caseInsensitiveEquality() !void {
    try std.testing.expect(ascii.equalsIgnoreCase(strings.EMPTY, strings.EMPTY));
    try std.testing.expect(ascii.equalsIgnoreCase(strings.ASCII_CASE_LOWER, strings.ASCII_CASE_UPPER));
    try std.testing.expect(ascii.equalsIgnoreCase(strings.ASCII_CASE_UPPER, strings.ASCII_CASE_MIXED));
    try std.testing.expect(!ascii.equalsIgnoreCase(strings.EMPTY, strings.ASCII_CASE_LOWER));
    try std.testing.expect(!ascii.equalsIgnoreCase(strings.ASCII_CASE_LOWER, strings.ASCII_CASE_LONGER));
    try std.testing.expect(!ascii.equalsIgnoreCase(strings.ASCII_CASE_LONGER, strings.ASCII_CASE_LOWER));
    try std.testing.expect(!ascii.equalsIgnoreCase(strings.ASCII_CASE_LOWER, strings.ASCII_CASE_DIFFERENT));
    try std.testing.expect(!ascii.equalsIgnoreCase(strings.ASCII_PUNCTUATION_LEFT, strings.ASCII_PUNCTUATION_RIGHT));
    try std.testing.expect(ascii.equalsIgnoreCase(&.{ 0x61, 0x00, 0xff }, &.{ 0x41, 0x00, 0xff }));
    try std.testing.expect(!ascii.equalsIgnoreCase(&.{0xc0}, &.{0xe0}));
}

pub fn copyShortSource() !void {
    var destination = [_]u8{0xcc} ** 7;

    const length = ascii.copyBounded(destination[1..6], strings.ASCII_SHORT_SOURCE);

    try std.testing.expectEqual(@as(usize, 2), length);
    try std.testing.expectEqualSlices(u8, &.{ 0xcc, 0x41, 0x42, 0xcc, 0xcc, 0xcc, 0xcc }, &destination);
}

pub fn copyExactAndTruncated() !void {
    var truncated = [_]u8{0xcc} ** 5;
    var exact = [_]u8{0xcc} ** 5;
    const embedded_zero = [_]u8{ 0x41, 0x00, 0x42 };

    try std.testing.expectEqual(@as(usize, 3), ascii.copyBounded(truncated[1..4], strings.ASCII_COPY_SOURCE));
    try std.testing.expectEqualSlices(u8, &.{ 0xcc, 0x41, 0x42, 0x43, 0xcc }, &truncated);
    try std.testing.expectEqual(@as(usize, 3), ascii.copyBounded(exact[1..4], &embedded_zero));
    try std.testing.expectEqualSlices(u8, &.{ 0xcc, 0x41, 0x00, 0x42, 0xcc }, &exact);
}

pub fn copyEmptySpans() !void {
    var destination = [_]u8{0xcc} ** 4;

    try std.testing.expectEqual(@as(usize, 0), ascii.copyBounded(destination[1..3], strings.EMPTY));
    try std.testing.expectEqual(@as(usize, 0), ascii.copyBounded(destination[1..1], strings.ASCII_COPY_SOURCE));
    try std.testing.expectEqual(@as(usize, 0), ascii.copyBounded(destination[1..1], strings.EMPTY));
    try std.testing.expectEqualSlices(u8, &.{ 0xcc, 0xcc, 0xcc, 0xcc }, &destination);
}

pub fn widenShortSource() !void {
    var destination = [_]u16{0xbeef} ** 7;

    const length = ascii.widenToUtf16(destination[1..6], strings.ASCII_SHORT_SOURCE);

    try std.testing.expectEqual(@as(usize, 2), length);
    try std.testing.expectEqualSlices(u16, &.{ 0xbeef, 0x0041, 0x0042, 0xbeef, 0xbeef, 0xbeef, 0xbeef }, &destination);
}

pub fn widenExactAndTruncated() !void {
    var truncated = [_]u16{0xbeef} ** 5;
    var exact = [_]u16{0xbeef} ** 5;
    const embedded_zero = [_]u8{ 0x41, 0x00, 0x42 };

    try std.testing.expectEqual(@as(usize, 3), ascii.widenToUtf16(truncated[1..4], strings.ASCII_COPY_SOURCE));
    try std.testing.expectEqualSlices(u16, &.{ 0xbeef, 0x0041, 0x0042, 0x0043, 0xbeef }, &truncated);
    try std.testing.expectEqual(@as(usize, 3), ascii.widenToUtf16(exact[1..4], &embedded_zero));
    try std.testing.expectEqualSlices(u16, &.{ 0xbeef, 0x0041, 0x0000, 0x0042, 0xbeef }, &exact);
}

pub fn widenEmptySpans() !void {
    var destination = [_]u16{0xbeef} ** 4;

    try std.testing.expectEqual(@as(usize, 0), ascii.widenToUtf16(destination[1..3], strings.EMPTY));
    try std.testing.expectEqual(@as(usize, 0), ascii.widenToUtf16(destination[1..1], strings.ASCII_COPY_SOURCE));
    try std.testing.expectEqual(@as(usize, 0), ascii.widenToUtf16(destination[1..1], strings.EMPTY));
    try std.testing.expectEqualSlices(u16, &.{ 0xbeef, 0xbeef, 0xbeef, 0xbeef }, &destination);
}
