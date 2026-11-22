//! Single Attached Read-Only Guest Disk And Disposable Checkpoint Graph

const std = @import("std");

const paths = @import("tests").runner.machine.paths;
const protocol = @import("tests").runner.transport.protocol;
const strings = @import("tests").runner.strings.runner;
const types = @import("tests").runner.types.host;

const Value = std.json.Value;

pub fn arguments(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), inputs: *const types.Paths) !void {
    try block(allocator, list, .{ .driver = strings.RAW, .@"node-name" = strings.FLASH_CODE, .@"read-only" = true, .file = file(inputs.FirmwareCode) });
    try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.FLASH_VARS, .file = file(inputs.Variables) });
    try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.STATE, .file = file(inputs.State) });
    if (inputs.BootOverlay) |overlay| {
        try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.DISK, .file = file(overlay), .backing = .{
            .driver = strings.RAW,
            .@"read-only" = true,
            .file = file(inputs.Image),
        } });
        try list.appendSlice(allocator, &.{ strings.DEVICE_FLAG, strings.AHCI_CONTROLLER, strings.DEVICE_FLAG, strings.AHCI_DEVICE });
        const data = inputs.DataDisk orelse return error.WrongGuest;
        const secondary = inputs.DataOverlay orelse return error.WrongGuest;
        try block(allocator, list, .{ .driver = strings.QCOW2, .@"node-name" = strings.DATA_DISK, .file = file(secondary), .backing = .{
            .driver = strings.RAW,
            .@"read-only" = true,
            .file = file(data),
        } });
        try list.appendSlice(allocator, &.{ strings.DEVICE_FLAG, strings.DATA_CONTROLLER, strings.DEVICE_FLAG, strings.DATA_DEVICE });
    } else {
        try block(allocator, list, .{ .driver = strings.RAW, .@"node-name" = strings.DISK, .@"read-only" = true, .file = file(inputs.Image) });
        try list.appendSlice(allocator, &.{ strings.DEVICE_FLAG, strings.BOOT_DEVICE });
    }
}

fn file(filename: []const u8) struct { driver: []const u8, filename: []const u8 } {
    return .{ .driver = strings.FILE_DRIVER, .filename = filename };
}

fn block(allocator: std.mem.Allocator, list: *std.ArrayList([]const u8), value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(allocator, value, .{});
    try list.appendSlice(allocator, &.{ strings.BLOCKDEV_FLAG, json });
}

pub fn verifyAttached(allocator: std.mem.Allocator, connection: *types.Connection, inputs: *const types.Paths) !void {
    const reply = try protocol.command(allocator, connection, strings.QUERY_BLOCK, null);
    defer reply.deinit();
    const devices = protocol.returned(reply);
    if (devices != .array) return error.WrongGuest;
    var code = false;
    var variables = false;
    var boot = false;
    var secondary = false;
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
            const valid = if (inputs.BootOverlay) |overlay|
                try matches(allocator, node, overlay, strings.QCOW2, false, inputs.Image)
            else
                try matches(allocator, node, inputs.Image, strings.RAW, true, null);
            if (boot or !valid) return error.WrongGuest;
            boot = true;
        } else if (std.mem.eql(u8, name, strings.DATA_DISK)) {
            const path = inputs.DataDisk orelse return error.WrongGuest;
            const overlay = inputs.DataOverlay orelse return error.WrongGuest;
            if (secondary or !try matches(allocator, node, overlay, strings.QCOW2, false, path)) return error.WrongGuest;
            secondary = true;
        } else return error.WrongGuest;
    }
    if (!code or !variables or !boot or secondary != (inputs.DataDisk != null)) return error.WrongGuest;
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
