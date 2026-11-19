//! Deterministic Firmware Only Multi Level AFS Inputs

const std = @import("std");

const inputs = @import("../../../tests/efi/constants/firmware/storage.zig");
const strings = @import("../../../tests/efi/strings/firmware/storage.zig");

pub fn add(builder: *std.Build, stage: *std.Build.Step.WriteFile) void {
    for (0..inputs.UNIT_COUNT) |index| {
        var identity: [inputs.IDENTITY_BYTES]u8 = @splat(inputs.NAME_BYTE);
        const value = index * inputs.IDENTITY_STRIDE;
        const suffix = identity.len - inputs.SUFFIX_BYTES;
        identity[suffix] = inputs.DIGIT_ZERO + @as(u8, @intCast(value / inputs.DECIMAL_HUNDREDS));
        identity[suffix + 1] = inputs.DIGIT_ZERO + @as(u8, @intCast(value / inputs.DECIMAL_TENS % inputs.DECIMAL_TENS));
        identity[suffix + 2] = inputs.DIGIT_ZERO + @as(u8, @intCast(value % inputs.DECIMAL_TENS));
        var payload: [inputs.PAYLOAD_BYTES]u8 = undefined;
        std.mem.writeInt(u32, payload[0..inputs.PAYLOAD_INDEX_BYTES], @intCast(index), .little);
        @memcpy(payload[inputs.PAYLOAD_INDEX_BYTES..], &inputs.PAYLOAD_SUFFIX);
        const location = builder.fmt(strings.LOCATION_FORMAT, .{&identity});
        _ = stage.add(location, &payload);
    }
}
