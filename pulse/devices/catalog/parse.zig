//! Parse An Installed Driver Description Using World Syntax

const std = @import("std");

const limits = @import("pulse").devices.constants.catalog.limits;
const schema = @import("pulse").devices.strings.schema;
const syntax = @import("shared").world.parse.syntax;
const values = @import("shared").world.parse.values;

const Descriptor = @import("pulse").devices.types.catalog.records.Descriptor;
const Kind = @import("shared").device.types.instance.Kind;
const Node = @import("shared").world.types.parse.syntax.Node;
const Selector = @import("pulse").devices.types.catalog.records.Selector;
const Value = @import("shared").world.types.parse.syntax.Value;

pub fn manifest(allocator: std.mem.Allocator, bytes: []const u8) !Descriptor {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nodes = try syntax.parse(&arena, bytes);
    var root: ?usize = null;
    var match: ?Selector = null;
    for (nodes, 0..) |node, index| {
        if (node.Disabled) continue;
        if (node.Parent) |parent| {
            if (root != parent or match != null) return error.InvalidManifest;
            match = try selector(node);
        } else {
            if (root != null) return error.InvalidManifest;
            try version(node);
            root = index;
        }
    }
    return .{ .Match = match orelse return error.InvalidManifest };
}

pub fn kind(value: Value) !Kind {
    if (!value.Quoted) return error.InvalidManifest;
    if (same(value.Text, schema.KEYBOARD)) return .Keyboard;
    if (same(value.Text, schema.FRAMEBUFFER)) return .Framebuffer;
    if (same(value.Text, schema.AHCI)) return .Ahci;
    return error.InvalidManifest;
}

pub fn number(value: Value) !u64 {
    return values.unsigned(value) catch error.InvalidManifest;
}

fn selector(node: Node) !Selector {
    if (!same(node.Name, schema.MATCH) or node.Arguments.len != 1) return error.InvalidManifest;
    var result: Selector = .{ .Kind = try kind(node.Arguments[0]) };
    for (node.Properties) |property| {
        if (!same(property.Name, schema.LOCATION)) return error.InvalidManifest;
        result.Location = try number(property.Value);
    }
    return result;
}

fn version(node: Node) !void {
    if (!same(node.Name, schema.DRIVER) or node.Arguments.len != 0) return error.InvalidManifest;
    var format: ?u64 = null;
    var abi: ?u64 = null;
    var protocol: ?u64 = null;
    for (node.Properties) |property| {
        const value = try number(property.Value);
        if (same(property.Name, schema.VERSION)) format = value else if (same(property.Name, schema.ABI)) abi = value else if (same(property.Name, schema.PROTOCOL)) protocol = value else return error.InvalidManifest;
    }
    if (format == null or abi == null or protocol == null) return error.InvalidManifest;
    if (format != limits.DESCRIPTOR_VERSION or abi != limits.ABI_VERSION or protocol != limits.PROTOCOL_VERSION) return error.UnsupportedVersion;
}

fn same(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}
