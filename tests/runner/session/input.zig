//! Fresh PS/2 IRQ Evidence For The Visible Device Boot

const std = @import("std");

const inputs = @import("tests").constants.drivers;
const labels = @import("tests").strings.drivers;
const markers = @import("tests").phase.strings.serial;
const strings = @import("tests").runner.strings.runner;
const types = @import("tests").runner.types.input;

pub fn choose() types.Keys {
    comptime std.debug.assert(labels.KEY_NAMES.len == inputs.MAKE_CODES.len);
    var keys: types.Keys = undefined;
    for (keys[0..inputs.CHALLENGE_TAPS]) |*key| {
        const index = std.crypto.random.uintLessThan(usize, labels.KEY_NAMES.len);
        key.* = .{ .Name = labels.KEY_NAMES[index], .Make = inputs.MAKE_CODES[index] };
    }
    keys[inputs.CHALLENGE_TAPS] = .{ .Name = labels.TERMINATOR_NAME, .Make = inputs.TERMINATOR_MAKE };
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
        if (std.mem.eql(u8, line, labels.READY)) {
            if (challenge.State != .Ready) return error.UnexpectedKeyboardInput;
            challenge.State = .Send;
        } else if (challenge.State != .Ready and std.mem.startsWith(u8, line, labels.SCANCODE_PREFIX)) {
            try scancode(challenge, line[labels.SCANCODE_PREFIX.len..]);
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

fn partialScancode(tail: []const u8) bool {
    return tail.len != 0 and (std.mem.startsWith(u8, tail, labels.SCANCODE_PREFIX) or
        std.mem.startsWith(u8, labels.SCANCODE_PREFIX, tail));
}

fn scancode(challenge: *types.Challenge, text: []const u8) !void {
    const byte = std.fmt.parseInt(u8, text, 16) catch return error.UnexpectedKeyboardInput;
    switch (challenge.State) {
        .Make => {
            if (byte != challenge.Keys[challenge.Index].Make) return error.UnexpectedKeyboardInput;
            challenge.State = .Break;
        },
        .Break => {
            if (byte != (challenge.Keys[challenge.Index].Make | inputs.BREAK_MASK)) return error.UnexpectedKeyboardInput;
            challenge.Index += 1;
            challenge.State = if (challenge.Index == challenge.Keys.len) .Done else .Send;
        },
        else => return error.UnexpectedKeyboardInput,
    }
}
