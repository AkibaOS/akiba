//! Fresh PS/2 IRQ Evidence For The Visible Device Boot

const std = @import("std");

const inputwire = @import("tests").phase.strings.input;
const keycodes = @import("tests").phase.constants.input;
const markers = @import("tests").phase.strings.serial;
const strings = @import("tests").runner.strings.runner;
const types = @import("tests").runner.types.input;

pub fn choose() types.Keys {
    comptime std.debug.assert(inputwire.KEY_NAMES.len == keycodes.MAKE_CODES.len);
    var keys: types.Keys = undefined;
    for (keys[0..keycodes.CHALLENGE_TAPS]) |*key| {
        const index = std.crypto.random.uintLessThan(usize, inputwire.KEY_NAMES.len);
        key.* = .{ .Name = inputwire.KEY_NAMES[index], .Make = keycodes.MAKE_CODES[index] };
    }
    keys[keycodes.CHALLENGE_TAPS] = .{ .Name = inputwire.EDITING_NAME, .Make = keycodes.EDITING_MAKE };
    keys[keycodes.CHALLENGE_TAPS + 1] = .{ .Name = inputwire.TERMINATOR_NAME, .Make = keycodes.TERMINATOR_MAKE };
    return keys;
}

pub fn sent(challenge: *types.Challenge) void {
    std.debug.assert(challenge.State == .Send);
    challenge.State = .Make;
}

pub fn observe(challenge: *types.Challenge, bytes: []const u8) !types.Action {
    if (challenge.Offset > bytes.len) return error.SerialHistoryLost;
    while (std.mem.indexOfScalarPos(u8, bytes, challenge.Offset, '\n')) |end| {
        const line = std.mem.trimEnd(u8, bytes[challenge.Offset..end], strings.CARRIAGE_RETURN);
        challenge.Offset = end + 1;
        if (std.mem.eql(u8, line, inputwire.READY)) {
            if (challenge.State != .Ready) return error.UnexpectedKeyboardInput;
            challenge.State = .Send;
        } else if (challenge.State != .Ready and std.mem.startsWith(u8, line, inputwire.SCANCODE_PREFIX)) {
            try scancode(challenge, line[inputwire.SCANCODE_PREFIX.len..]);
        } else if (challenge.State != .Done and std.mem.startsWith(u8, line, markers.COMPLETE)) {
            return error.MissingInjectedInput;
        }
    }
    return switch (challenge.State) {
        .Send => if (challenge.Offset == bytes.len) .Inject else .Waiting,
        .Done => if (partialScancode(bytes[challenge.Offset..])) .Waiting else .Complete,
        else => .Waiting,
    };
}

pub fn verifyEvents(bytes: []const u8, keys: []const types.Key) !void {
    var index: usize = 0;
    var lines = std.mem.splitScalar(u8, bytes, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, strings.CARRIAGE_RETURN);
        if (!std.mem.startsWith(u8, line, inputwire.EVENT_PREFIX)) continue;
        if (lines.index == null or index >= keys.len) return error.UnexpectedKeyboardInput;
        var columns = std.mem.splitScalar(u8, line[inputwire.EVENT_PREFIX.len..], ' ');
        const kind = std.fmt.parseInt(u8, columns.next() orelse return error.UnexpectedKeyboardInput, 10) catch return error.UnexpectedKeyboardInput;
        const value = std.fmt.parseInt(u32, columns.next() orelse return error.UnexpectedKeyboardInput, 10) catch return error.UnexpectedKeyboardInput;
        if (columns.next() != null) return error.UnexpectedKeyboardInput;
        const key = keys[index];
        if (key.Make == keycodes.EDITING_MAKE) {
            if (kind != keycodes.EDITING_KIND or value != keycodes.BACKSPACE_EVENT) return error.UnexpectedKeyboardInput;
        } else if (key.Name.len != 1 or kind != keycodes.TEXT_KIND or value != key.Name[0]) return error.UnexpectedKeyboardInput;
        index += 1;
    }
    if (index != keys.len) return error.MissingInjectedInput;
}

fn partialScancode(tail: []const u8) bool {
    return tail.len != 0 and (std.mem.startsWith(u8, tail, inputwire.SCANCODE_PREFIX) or
        std.mem.startsWith(u8, inputwire.SCANCODE_PREFIX, tail));
}

fn scancode(challenge: *types.Challenge, text: []const u8) !void {
    const byte = std.fmt.parseInt(u8, text, 16) catch return error.UnexpectedKeyboardInput;
    switch (challenge.State) {
        .Make => {
            if (byte != challenge.Keys[challenge.Index].Make) return error.UnexpectedKeyboardInput;
            challenge.State = .Break;
        },
        .Break => {
            if (byte != (challenge.Keys[challenge.Index].Make | keycodes.BREAK_MASK)) return error.UnexpectedKeyboardInput;
            challenge.Index += 1;
            challenge.State = if (challenge.Index == challenge.Keys.len) .Done else .Send;
        },
        else => return error.UnexpectedKeyboardInput,
    }
}
