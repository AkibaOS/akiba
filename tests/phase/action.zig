//! Fixed Width Session Action Validation

const std = @import("std");

const constants = @import("tests").phase.constants.action;
const types = @import("tests").phase.types.action;

pub fn encode(epoch: u64, action: types.Action) ?types.Frame {
    if (epoch == 0 or action == .Timeout) return null;
    var frame: types.Frame = undefined;
    @memcpy(frame[0..constants.EPOCH_OFFSET], &constants.HEADER);
    std.mem.writeInt(u64, frame[constants.EPOCH_OFFSET..constants.ACTION_OFFSET], epoch, .little);
    frame[constants.ACTION_OFFSET] = @intFromEnum(action);
    return frame;
}

pub fn decode(frame: []const u8, expected_epoch: u64, mode: types.Mode) ?types.Action {
    if (mode == .Closed or expected_epoch == 0 or frame.len != constants.FRAME_BYTES or
        !std.mem.eql(u8, frame[0..constants.EPOCH_OFFSET], &constants.HEADER)) return null;
    const epoch = std.mem.readInt(u64, frame[constants.EPOCH_OFFSET..constants.ACTION_OFFSET], .little);
    if (epoch != expected_epoch) return null;
    const action = std.enums.fromInt(types.Action, frame[constants.ACTION_OFFSET]) orelse return null;
    return switch (mode) {
        .Closed => null,
        .Testing => if (action == .Cancel) action else null,
        .Menu => if (action == .Boot or action == .Shutdown) action else null,
    };
}
