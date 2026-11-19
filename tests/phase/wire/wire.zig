//! Encode And Validate Test Phase Frames

const std = @import("std");

const constants = @import("tests").phase.constants.wire;
const types = @import("tests").phase.types.ticket;

pub fn advanceGreeting(marker: []const u8, matched: usize, byte: u8) usize {
    std.debug.assert(matched < marker.len);
    if (byte == marker[matched]) return matched + 1;
    return @intFromBool(byte == marker[0]);
}

pub fn encode(ticket: types.Ticket, role: types.Role) ?types.Frame {
    if (ticket.Epoch == 0) return null;
    const scenario = switch (ticket.Scenario) {
        .Standard => constants.STANDARD,
        .PulseDeath => constants.PULSE_DEATH,
        .Devices => constants.DEVICES,
        .Collapse => constants.COLLAPSE,
        .Firmware => return null,
    };
    var frame: types.Frame = undefined;
    @memcpy(frame[0..constants.EPOCH_OFFSET], header(role));
    std.mem.writeInt(u64, frame[constants.EPOCH_OFFSET..constants.SCENARIO_OFFSET], ticket.Epoch, .little);
    frame[constants.SCENARIO_OFFSET] = scenario;
    return frame;
}

pub fn decode(frame: []const u8, role: types.Role) ?types.Ticket {
    if (frame.len != constants.FRAME_BYTES or !std.mem.eql(u8, frame[0..constants.EPOCH_OFFSET], header(role))) return null;
    const epoch = std.mem.readInt(u64, frame[constants.EPOCH_OFFSET..constants.SCENARIO_OFFSET], .little);
    if (epoch == 0) return null;
    return .{
        .Epoch = epoch,
        .Scenario = switch (frame[constants.SCENARIO_OFFSET]) {
            constants.STANDARD => .Standard,
            constants.PULSE_DEATH => .PulseDeath,
            constants.DEVICES => .Devices,
            constants.COLLAPSE => .Collapse,
            else => return null,
        },
    };
}

pub fn acknowledges(expected: types.Ticket, frame: []const u8) bool {
    const actual = decode(frame, .Acknowledgement) orelse return false;
    return actual.Epoch == expected.Epoch and actual.Scenario == expected.Scenario;
}

fn header(role: types.Role) *const [constants.EPOCH_OFFSET]u8 {
    return switch (role) {
        .Offer => &constants.OFFER,
        .Acknowledgement => &constants.ACKNOWLEDGEMENT,
    };
}
