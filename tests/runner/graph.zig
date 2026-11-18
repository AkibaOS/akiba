//! Single Attached Read-Only Guest Disk And Disposable Checkpoint Graph

const std = @import("std");

const paths = @import("tests").runner.paths;
const protocol = @import("tests").runner.protocol;
const strings = @import("tests").strings.runner;
const types = @import("tests").types.host;

const Value = std.json.Value;

pub fn arguments(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), inputs: *const types.Paths) !void {
    try block(allocator, list, .{ .driver = strings.RAW, .@"node-name" = strings.FLASH_CODE, .@"read-only" = true, .file = file(inputs.FirmwareCode) });
    try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.FLASH_VARS, .file = file(inputs.Variables) });
    try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.STATE, .file = file(inputs.State) });
    try block(allocator, list, .{ .driver = strings.FILE_DRIVER, .@"node-name" = strings.FIRMWARE_MEDIA, .filename = inputs.FirmwareImage, .@"read-only" = true });
    try block(allocator, list, .{ .driver = strings.FILE_DRIVER, .@"node-name" = strings.MIRAI_MEDIA, .filename = inputs.Image, .@"read-only" = true });
    try block(allocator, list, disk(strings.MIRAI_MEDIA));
    try list.appendSlice(allocator, &.{ strings.DEVICE_FLAG, strings.BOOT_DEVICE });
}

fn file(filename: []const u8) struct { driver: []const u8, filename: []const u8 } {
    return .{ .driver = strings.FILE_DRIVER, .filename = filename };
}

fn disk(node: []const u8) struct { driver: []const u8, @"node-name": []const u8, @"read-only": bool, file: []const u8 } {
    return .{ .driver = strings.RAW, .@"node-name" = strings.DISK, .@"read-only" = true, .file = node };
}

fn block(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, value, .{});
    try list.appendSlice(allocator, &.{ strings.BLOCKDEV_FLAG, json });
}

pub fn select(allocator: std.mem.Allocator, connection: *types.Connection, firmware: bool) !void {
    const node = if (firmware) strings.FIRMWARE_MEDIA else strings.MIRAI_MEDIA;
    const json = try std.json.Stringify.valueAlloc(allocator, .{ .options = .{disk(node)} }, .{});
    defer allocator.free(json);
    try protocol.action(allocator, connection, strings.REOPEN, json);
}

pub fn verifyAttached(allocator: std.mem.Allocator, connection: *types.Connection, inputs: *const types.Paths, firmware: bool) !void {
    const reply = try protocol.command(allocator, connection, strings.QUERY_BLOCK, null);
    defer reply.deinit();
    const devices = protocol.returned(reply);
    if (devices != .array) return error.WrongGuest;
    var code = false;
    var variables = false;
    var boot = false;
    for (devices.array.items) |device| {
        const node = protocol.field(device, strings.INSERTED) orelse continue;
        const name = protocol.text(node, strings.NODE) orelse return error.WrongGuest;
        if (std.mem.eql(u8, name, strings.FLASH_CODE)) {
            if (code or !try matches(allocator, node, inputs.FirmwareCode, strings.RAW, true, null)) return error.WrongGuest;
            code = true;
        } else if (std.mem.eql(u8, name, strings.FLASH_VARS)) {
            if (variables or !try matches(allocator, node, inputs.Variables, strings.QCOW2, false, inputs.FirmwareTemplate)) return error.WrongGuest;
            variables = true;
        } else if (std.mem.eql(u8, name, strings.DISK)) {
            const path = if (firmware) inputs.FirmwareImage else inputs.Image;
            if (boot or !try matches(allocator, node, path, strings.RAW, true, null)) return error.WrongGuest;
            boot = true;
        } else return error.WrongGuest;
    }
    if (!code or !variables or !boot) return error.WrongGuest;
}

pub fn verifyStateStore(allocator: std.mem.Allocator, connection: *types.Connection, inputs: *const types.Paths) !void {
    const reply = try protocol.command(allocator, connection, strings.QUERY_NODES, null);
    defer reply.deinit();
    const nodes = protocol.returned(reply);
    if (nodes != .array) return error.WrongGuest;
    var state = false;
    for (nodes.array.items) |node| {
        if (!protocol.equal(node, strings.NODE, strings.STATE)) continue;
        if (state or !try matches(allocator, node, inputs.State, strings.QCOW2, false, null)) return error.WrongGuest;
        state = true;
    }
    if (!state) return error.WrongGuest;
}

fn matches(allocator: std.mem.Allocator, node: Value, path: []const u8, format: []const u8, readonly: bool, expected_backing: ?[]const u8) !bool {
    if (!protocol.boolean(node, strings.READONLY, readonly) or !protocol.boolean(node, strings.ACTIVE, true)) return false;
    const image = protocol.field(node, strings.IMAGE) orelse return false;
    if (!try imageMatches(allocator, image, path, format)) return false;
    const backing = protocol.field(image, strings.BACKING_IMAGE);
    if (expected_backing) |expected| {
        if (!try imageMatches(allocator, backing orelse return false, expected, strings.RAW)) return false;
    } else if (backing != null) return false;
    return true;
}

fn imageMatches(allocator: std.mem.Allocator, image: Value, path: []const u8, format: []const u8) !bool {
    if (!protocol.equal(image, strings.FORMAT, format)) return false;
    return paths.same(allocator, path, protocol.text(image, strings.FILENAME) orelse return false);
}
