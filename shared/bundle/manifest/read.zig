//! Read One Common Manifest Into Owned Typed Facts

const std = @import("std");

const limits = @import("shared").bundle.constants.contract;
const names = @import("shared").bundle.manifest.names;
const schema = @import("shared").bundle.strings.schema;
const syntax = @import("shared").world.parse.syntax;
const values = @import("shared").world.parse.values;

const Descriptor = @import("shared").bundle.types.manifest.descriptor.Descriptor;
const Interface = @import("shared").bundle.types.manifest.descriptor.Interface;
const Kind = @import("shared").device.types.instance.Kind;
const ManifestError = @import("shared").bundle.errors.manifest.schema.ManifestError;
const Node = @import("shared").world.types.parse.syntax.Node;

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) ManifestError!Descriptor {
    if (bytes.len > limits.MAX_MANIFEST_BYTES) return error.TooLarge;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const nodes = syntax.parse(&arena, bytes) catch |failure| switch (failure) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidWorld => return error.InvalidManifest,
    };
    var root: ?usize = null;
    var description: Descriptor = undefined;
    for (nodes, 0..) |node, index| {
        if (node.Disabled) continue;
        if (node.Parent) |parent| {
            if (root != parent) return error.InvalidManifest;
            try add(&description, node);
        } else {
            if (root != null) return error.InvalidManifest;
            description = try header(node);
            root = index;
        }
    }
    if (root == null) return error.InvalidManifest;
    return description;
}

pub fn supports(description: Descriptor, provider: Interface, hardware: Kind, version: u64) bool {
    return description.Type == .Driver and description.Provides.get(provider) == version and description.Matches.contains(hardware);
}

fn header(node: Node) ManifestError!Descriptor {
    if (!equal(node.Name, schema.BUNDLE) or node.Arguments.len != 0) return error.InvalidManifest;
    for (node.Properties) |property| {
        if (!equal(property.Name, schema.VERSION) and !equal(property.Name, schema.ABI) and
            !equal(property.Name, schema.TYPE)) return error.InvalidManifest;
    }
    const version = try number(node, schema.VERSION);
    const abi = try number(node, schema.ABI);
    const kind = values.text(values.property(node, schema.TYPE) orelse return error.InvalidManifest) catch return error.InvalidManifest;
    if (version != limits.VERSION) return error.UnsupportedVersion;
    if (abi != limits.ABI) return error.UnsupportedABI;
    return .{ .Type = names.bundleType(kind) orelse return error.UnsupportedType };
}

fn add(description: *Descriptor, node: Node) ManifestError!void {
    if (node.Arguments.len != 1) return error.InvalidManifest;
    const argument = values.text(node.Arguments[0]) catch return error.InvalidManifest;
    if (equal(node.Name, schema.PROVIDES)) {
        for (node.Properties) |property| {
            if (!equal(property.Name, schema.VERSION)) return error.InvalidManifest;
        }
        const provider = names.interface(argument) orelse return error.InvalidManifest;
        if (description.Provides.get(provider) != null) return error.InvalidManifest;
        description.Provides.set(provider, try number(node, schema.VERSION));
    } else if (equal(node.Name, schema.MATCHES)) {
        if (node.Properties.len != 0) return error.InvalidManifest;
        const kind = names.hardware(argument) orelse return error.InvalidManifest;
        if (description.Matches.contains(kind)) return error.InvalidManifest;
        description.Matches.insert(kind);
    } else return error.InvalidManifest;
}

fn number(node: Node, key: []const u8) ManifestError!u64 {
    return values.unsigned(values.property(node, key) orelse return error.InvalidManifest) catch error.InvalidManifest;
}

fn equal(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}
