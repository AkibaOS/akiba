//! Actual ESP Capacity And Partition Boundary Regressions

const std = @import("std");

const capacity = @import("tests").fast.image.constants.capacity;
const constants = @import("tests").fast.image.constants.emission;
const fixture = @import("tests").fast.image.fixture;
const inputs = @import("tests").fast.constants.image.fixtures;
const io = @import("tests").fast.image.io;
const names = @import("tests").fast.strings.image.witnesses;
const tool = @import("mkafsdisk");

pub fn bootloaderCannotConsumeTheNextPartitionSector() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    {
        const source = try temporary.dir.openFile(names.BOOTLOADER_PATH, .{ .mode = .write_only });
        defer source.close();
        try source.setEndPos(constants.ESP_FILE_BYTES);
    }
    const file = try temporary.dir.createFile(names.IMAGE_NAME, .{ .read = true });
    defer file.close();
    try file.setEndPos(inputs.IMAGE_BYTES);
    const guard = [_]u8{capacity.FILL_BYTE} ** inputs.SECTOR_BYTES;
    try file.pwriteAll(&guard, capacity.PARTITION_START);
    try std.testing.expectError(error.EspTooSmall, tool.image.esp.createEsp(std.testing.allocator, file, paths.Source, @intCast(capacity.ESP_FIRST), inputs.ESP_SECTORS));
    var actual: [inputs.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, capacity.PARTITION_START, &actual);
    try std.testing.expectEqualSlices(u8, &guard, &actual);
}
