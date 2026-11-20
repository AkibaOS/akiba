//! Bind EFI Image Selection To One Host Boot Epoch

const std = @import("std");

const constants = @import("tests").phase.constants.boot.frame;
const types = @import("tests").phase.types.boot.frame;

pub fn encode(selection: types.Selection, kind: types.Kind) ?types.Frame {
    if (selection.Epoch == 0) return null;
    var bytes: types.Frame = undefined;
    const prefix = marker(kind);
    bytes[0..prefix.len].* = prefix;
    std.mem.writeInt(u64, bytes[prefix.len..constants.ROLE_OFFSET], selection.Epoch, .little);
    bytes[constants.ROLE_OFFSET] = @intFromEnum(selection.Role);
    return bytes;
}

pub fn decode(bytes: []const u8, kind: types.Kind) ?types.Selection {
    const prefix = marker(kind);
    if (bytes.len != constants.FRAME_BYTES or !std.mem.eql(u8, bytes[0..prefix.len], &prefix)) return null;
    const epoch = std.mem.readInt(u64, bytes[prefix.len..constants.ROLE_OFFSET], .little);
    if (epoch == 0) return null;
    const role = std.enums.fromInt(types.Role, bytes[constants.ROLE_OFFSET]) orelse return null;
    return .{ .Epoch = epoch, .Role = role };
}

pub fn acknowledges(selection: types.Selection, bytes: []const u8) bool {
    const expected = encode(selection, .Acknowledgement) orelse return false;
    return std.mem.eql(u8, &expected, bytes);
}

fn marker(kind: types.Kind) [constants.OFFER.len]u8 {
    return switch (kind) {
        .Offer => constants.OFFER,
        .Acknowledgement => constants.ACKNOWLEDGEMENT,
    };
}
