//! Normalized PS/2 Keyboard Driver Regressions

const std = @import("std");

const decode = @import("keyboard").input.decode;
const memory = @import("common").constants.memory;
const weaver = @import("weaver");

const Event = @import("shared").keyboard.types.event.Event;
const Key = @import("shared").keyboard.types.event.Key;
const State = @import("keyboard").types.input.state.State;

test "Set 1 text reflects modifiers and releases produce no duplicate text" {
    var state: State = .{};
    try expectText(decode.feed(&state, 0x1e), 'a');
    try std.testing.expect(decode.feed(&state, 0x9e) == null);
    try std.testing.expect(decode.feed(&state, 0x2a) == null);
    const upper = decode.feed(&state, 0x1e).?;
    try expectText(upper, 'A');
    try std.testing.expect(upper.Modifiers.Shift);
    try expectText(decode.feed(&state, 0x02), '!');
    try std.testing.expect(decode.feed(&state, 0xaa) == null);
    try std.testing.expect(decode.feed(&state, 0x3a) == null);
    try std.testing.expect(decode.feed(&state, 0x3a) == null);
    try expectText(decode.feed(&state, 0x1e), 'A');
    try std.testing.expect(decode.feed(&state, 0xba) == null);
    try std.testing.expect(decode.feed(&state, 0x3a) == null);
    try expectText(decode.feed(&state, 0x1e), 'a');
}

test "Editing and extended navigation use key events instead of text or raw codes" {
    var state: State = .{};
    try expectKey(decode.feed(&state, 0x0e), .Backspace);
    try expectKey(decode.feed(&state, 0x1c), .Enter);
    try std.testing.expect(decode.feed(&state, 0xe0) == null);
    try expectKey(decode.feed(&state, 0x4b), .Left);
    try std.testing.expect(decode.feed(&state, 0xe0) == null);
    try std.testing.expect(decode.feed(&state, 0xcb) == null);
    try std.testing.expect(decode.feed(&state, 0xe0) == null);
    try std.testing.expect(decode.feed(&state, 0x1d) == null);
    const tab = decode.feed(&state, 0x0f).?;
    try expectKey(tab, .Tab);
    try std.testing.expect(tab.Modifiers.Control);
    try std.testing.expect(decode.feed(&state, 0xe0) == null);
    try std.testing.expect(decode.feed(&state, 0x9d) == null);
    try std.testing.expect(!decode.feed(&state, 0x0f).?.Modifiers.Control);
}

test "Set 1 multibyte sequences do not accidentally hold modifiers" {
    var state: State = .{};
    const prefix = [_]u8{ 0xe1, 0x1d, 0x45, 0xe1, 0x9d };
    for (prefix) |byte| try std.testing.expect(decode.feed(&state, byte) == null);
    try expectKey(decode.feed(&state, 0xc5), .Pause);
    try std.testing.expect(decode.feed(&state, 0xe0) == null);
    try std.testing.expect(decode.feed(&state, 0x2a) == null);
    const text = decode.feed(&state, 0x1e).?;
    try expectText(text, 'a');
    try std.testing.expect(!text.Modifiers.Shift and !text.Modifiers.Control);
}

test "Weaver plans the exact installed keyboard ELF and its relocations" {
    const bytes = @embedFile("keyboardimage");
    const allocator = std.testing.allocator;
    const empty: u8 = 0;
    var graph = try weaver.library.load.collect.collect(allocator, .{ .Context = &empty, .ReadFromOrigin = noLibrary }, bytes);
    defer graph.deinit();
    var placement = try weaver.image.place.place(allocator, &graph, null, .{
        .MinimumAddress = memory.sizes.PAGE_SIZE,
        .MaximumAddress = memory.layout.USER_SPACE_END,
        .MaximumPages = memory.layout.USER_SPACE_END / memory.sizes.PAGE_SIZE,
    }, &.{});
    defer placement.deinit();
    var linked = try weaver.link.plan.plan(allocator, &placement);
    defer linked.deinit();
    try std.testing.expect(placement.Executable.Image.Entry != 0);
}

fn noLibrary(_: *const anyopaque, _: std.mem.Allocator, _: []const []const u8, _: []const u8) weaver.library.errors.library.ReadError!?[]u8 {
    return null;
}

fn expectText(event: ?Event, value: u32) !void {
    const actual = event orelse return error.TestUnexpectedResult;
    try std.testing.expect(actual.Kind == .Text and actual.Value == value);
}

fn expectKey(event: ?Event, value: Key) !void {
    const actual = event orelse return error.TestUnexpectedResult;
    try std.testing.expect(actual.Kind == .Key and actual.Value == @intFromEnum(value));
}
