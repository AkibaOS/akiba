//! Owned Host Inputs For Active AFS Writer Regressions

const std = @import("std");

const capacity = @import("tests").fast.image.constants.capacity;
const constants = @import("tests").fast.image.constants.emission;
const inputs = @import("tests").fast.constants.image.fixtures;
const io = @import("tests").fast.image.io;
const names = @import("tests").fast.strings.image.witnesses;
const strings = @import("tests").fast.image.strings.emission;
const types = @import("tests").fast.image.types.emission;

pub fn paths(allocator: std.mem.Allocator, directory: std.fs.Dir) !types.Paths {
    const root = try directory.realpathAlloc(allocator, names.CURRENT_DIRECTORY);
    defer allocator.free(root);
    const source = try std.fs.path.join(allocator, &.{ root, names.SOURCE_DIRECTORY });
    errdefer allocator.free(source);
    const output = try std.fs.path.join(allocator, &.{ root, names.IMAGE_NAME });
    return .{ .Allocator = allocator, .Source = source, .Output = output };
}

pub fn createSource(directory: std.fs.Dir, with_bootloader: bool) !void {
    try directory.makePath(names.BOOT_DIRECTORY);
    try directory.makePath(strings.NESTED_DIRECTORY);
    if (with_bootloader) try directory.writeFile(.{ .sub_path = names.BOOTLOADER_PATH, .data = &inputs.BOOTLOADER_BYTES });
}

pub fn addModerateUnits(directory: std.fs.Dir) !void {
    try addUnits(constants.MODERATE_NAME_BYTES, directory, constants.MODERATE_UNITS, 1);
}

pub fn addDeepUnits(directory: std.fs.Dir) !void {
    try addUnits(constants.DEEP_NAME_BYTES, directory, constants.DEEP_UNITS, constants.DEEP_STRIDE);
}

fn addUnits(comptime name_bytes: usize, directory: std.fs.Dir, count: usize, stride: usize) !void {
    var nested = try directory.openDir(strings.NESTED_DIRECTORY, .{});
    defer nested.close();
    for (0..count) |offset| {
        const index = count - offset - 1;
        var name: [name_bytes]u8 = undefined;
        identity(index * stride, &name);
        const bytes = payload(index);
        try nested.writeFile(.{ .sub_path = &name, .data = &bytes });
    }
}

pub fn addMutableUnit(directory: std.fs.Dir) !void {
    const bytes = payload(constants.MODERATE_UNITS);
    try directory.writeFile(.{ .sub_path = strings.MUTABLE_PATH, .data = &bytes });
}

pub fn identity(index: usize, destination: []u8) void {
    std.debug.assert(destination.len >= capacity.NAME_SUFFIX_BYTES and index <= capacity.AFTER_LAST_SUFFIX);
    @memset(destination, capacity.NAME_BYTE);
    const suffix = destination.len - capacity.NAME_SUFFIX_BYTES;
    destination[suffix] = capacity.DIGIT_ZERO + @as(u8, @intCast(index / capacity.DECIMAL_HUNDREDS));
    destination[suffix + 1] = capacity.DIGIT_ZERO + @as(u8, @intCast(index / capacity.DECIMAL_TENS % capacity.DECIMAL_TENS));
    destination[suffix + 2] = capacity.DIGIT_ZERO + @as(u8, @intCast(index % capacity.DECIMAL_TENS));
}

pub fn payload(index: usize) [constants.PAYLOAD_BYTES]u8 {
    var bytes: [constants.PAYLOAD_BYTES]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..constants.PAYLOAD_INDEX_BYTES], @intCast(index), .little);
    @memcpy(bytes[constants.PAYLOAD_INDEX_BYTES..], &constants.PAYLOAD_SUFFIX);
    return bytes;
}

pub fn addOversizedUnit(directory: std.fs.Dir) !void {
    const file = try directory.createFile(strings.OVERSIZED_PATH, .{});
    defer file.close();
    try file.setEndPos(constants.OVERSIZED_PAYLOAD_CELLS * capacity.CELL_BYTES);
}

pub fn writeSentinel(directory: std.fs.Dir) !void {
    try directory.writeFile(.{ .sub_path = names.IMAGE_NAME, .data = strings.SENTINEL });
}

pub fn expectSentinel(directory: std.fs.Dir) !void {
    const file = try directory.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    try std.testing.expectEqual(@as(u64, strings.SENTINEL.len), try file.getEndPos());
    var bytes: [strings.SENTINEL.len]u8 = undefined;
    try io.readExact(file, 0, &bytes);
    try std.testing.expectEqualSlices(u8, strings.SENTINEL, &bytes);
}

pub fn expectOwnedEntries(directory: std.fs.Dir, source_exists: bool, final_exists: bool) !void {
    var root = try directory.openDir(names.CURRENT_DIRECTORY, .{ .iterate = true });
    defer root.close();
    var iterator = root.iterate();
    var found_source = false;
    var found_final = false;
    while (try iterator.next()) |entry| {
        if (std.mem.eql(u8, entry.name, names.SOURCE_DIRECTORY)) {
            try std.testing.expect(!found_source);
            try std.testing.expectEqual(std.fs.File.Kind.directory, entry.kind);
            found_source = true;
        } else if (std.mem.eql(u8, entry.name, names.IMAGE_NAME)) {
            try std.testing.expect(!found_final);
            try std.testing.expectEqual(std.fs.File.Kind.file, entry.kind);
            found_final = true;
        } else {
            return error.TestUnexpectedResult;
        }
    }
    try std.testing.expectEqual(source_exists, found_source);
    try std.testing.expectEqual(final_exists, found_final);
}
