//! UTF-8 Regression Checks

const std = @import("std");

const constants = @import("tests").fast.constants.utils.vectors;
const fixtures = @import("tests").fast.types.utils.vectors;
const utf8 = @import("utils").text.utf8;

pub fn emptyInput() !void {
    const decoded = utf8.decode(&.{});

    try std.testing.expectEqual(@as(u32, 0xfffd), decoded.Codepoint);
    try std.testing.expectEqual(@as(u8, 1), decoded.Length);
}

pub fn validScalars() !void {
    try expectDecodedCases(&constants.UTF8_VALID_CASES);
}

pub fn invalidLeads() !void {
    try expectDecodedCases(&constants.UTF8_INVALID_LEAD_CASES);
}

pub fn truncatedSequences() !void {
    try expectDecodedCases(&constants.UTF8_TRUNCATED_CASES);
}

pub fn invalidContinuations() !void {
    try expectDecodedCases(&constants.UTF8_INVALID_CONTINUATION_CASES);
}

pub fn overlongSequences() !void {
    try expectDecodedCases(&constants.UTF8_OVERLONG_CASES);
}

pub fn surrogateScalars() !void {
    try expectDecodedCases(&constants.UTF8_SURROGATE_CASES);
}

pub fn outOfRangeScalars() !void {
    try expectDecodedCases(&constants.UTF8_OUT_OF_RANGE_CASES);
}

pub fn recoveryProgress() !void {
    const bytes = [_]u8{ 0xe2, 0x28, 0xa1, 0xc2, 0xa2, 0xed, 0xa0, 0x80, 0x41 };
    const codepoints = [_]u32{ 0xfffd, 0x28, 0xfffd, 0xa2, 0xfffd, 0x41 };
    const lengths = [_]u8{ 1, 1, 1, 2, 3, 1 };
    var position: usize = 0;

    for (codepoints, lengths) |codepoint, length| {
        const decoded = utf8.decode(bytes[position..]);
        try std.testing.expectEqual(codepoint, decoded.Codepoint);
        try std.testing.expectEqual(length, decoded.Length);
        try std.testing.expect(decoded.Length > 0);
        try std.testing.expect(decoded.Length <= bytes.len - position);
        position += decoded.Length;
    }
    try std.testing.expectEqual(bytes.len, position);
}

fn expectDecodedCases(cases: []const fixtures.UTF8Case) !void {
    for (cases) |case| {
        const decoded = utf8.decode(case.Bytes);
        try std.testing.expectEqual(case.Codepoint, decoded.Codepoint);
        try std.testing.expectEqual(case.Length, decoded.Length);
    }
}
