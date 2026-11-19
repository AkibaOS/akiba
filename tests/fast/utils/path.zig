//! Lexical Path Regression Checks

const std = @import("std");

const iterator = @import("utils").path.types.iterator;
const strings = @import("tests").fast.strings.utils;

pub fn emptyPaths() !void {
    for (strings.PATH_EMPTY_LOCATIONS) |location| {
        try expectComponents(location, &.{});
    }
}

pub fn mixedSeparators() !void {
    try expectComponents(strings.PATH_MIXED, &strings.PATH_MIXED_COMPONENTS);
}

pub fn lexicalComponents() !void {
    try expectComponents(strings.PATH_LEXICAL, &strings.PATH_LEXICAL_COMPONENTS);
    try expectComponents(strings.PATH_DEVICE, &strings.PATH_DEVICE_COMPONENTS);
    try expectComponents(strings.PATH_RELATIVE, &strings.PATH_RELATIVE_COMPONENTS);
}

pub fn independentIterators() !void {
    var first = iterator.LocationIterator.init(strings.PATH_MIXED);
    var second = iterator.LocationIterator.init(strings.PATH_RELATIVE);

    const first_component = first.next().?;
    try std.testing.expectEqualSlices(u8, strings.PATH_MIXED_COMPONENTS[0], first_component);
    try std.testing.expectEqual(@intFromPtr(strings.PATH_MIXED[3..8].ptr), @intFromPtr(first_component.ptr));
    try std.testing.expectEqualSlices(u8, strings.PATH_RELATIVE_COMPONENTS[0], second.next().?);
    try std.testing.expectEqualSlices(u8, strings.PATH_MIXED_COMPONENTS[1], first.next().?);
    try std.testing.expectEqualSlices(u8, strings.PATH_RELATIVE_COMPONENTS[1], second.next().?);
    try std.testing.expect(second.next() == null);
    try std.testing.expectEqualSlices(u8, strings.PATH_MIXED_COMPONENTS[2], first.next().?);
    try std.testing.expect(first.next() == null);
    try std.testing.expect(second.next() == null);
    try std.testing.expect(first.next() == null);
}

fn expectComponents(location: []const u8, expected: []const []const u8) !void {
    var components = iterator.LocationIterator.init(location);

    for (expected) |component| {
        const actual = components.next();
        try std.testing.expect(actual != null);
        try std.testing.expectEqualSlices(u8, component, actual.?);
    }
    try std.testing.expect(components.next() == null);
    try std.testing.expect(components.next() == null);
}
