//! Private Launch Startup Record Checks

const std = @import("std");

const shared = @import("shared");

pub fn preservesWire() !void {
    const startup = shared.launch.startup;
    const bytes = startup.encode(3, 0x1001);
    const expected = [24]u8{
        1, 0,  0, 0, 0, 0, 0, 0,
        3, 0,  0, 0, 0, 0, 0, 0,
        1, 16, 0, 0, 0, 0, 0, 0,
    };
    try std.testing.expectEqualSlices(u8, &expected, &bytes);
    try std.testing.expectEqual(@as(u64, 8192), try startup.decode(&bytes, 8192));
    try std.testing.expectEqual(@as(u64, 4096), try startup.size(1, 0, 4096));
}

pub fn rejectsOutOfBounds() !void {
    const startup = shared.launch.startup;
    var bytes = startup.encode(1, 0);
    bytes[0] = 2;
    try std.testing.expectError(error.InvalidStartup, startup.decode(&bytes, 4096));
    bytes = startup.encode(0, 0);
    try std.testing.expectError(error.InvalidStartup, startup.decode(&bytes, 4096));
    bytes = startup.encode(1, std.math.maxInt(u64));
    try std.testing.expectError(error.NoStartupSpace, startup.decode(&bytes, std.math.maxInt(u64)));
    bytes = startup.encode(1, std.math.maxInt(u64) - 30);
    try std.testing.expectError(error.NoStartupSpace, startup.decode(&bytes, std.math.maxInt(u64)));
    bytes = startup.encode(3, 0x1001);
    try std.testing.expectError(error.NoStartupSpace, startup.decode(&bytes, 8191));
}
