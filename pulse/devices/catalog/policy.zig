//! Load Explicit Installed Driver Selections From World

const std = @import("std");

const parse = @import("pulse").devices.catalog.parse;
const schema = @import("pulse").devices.strings.schema;
const syntax = @import("pulse").world.parse.syntax;
const unit = @import("shared").launch.service.request;

const Key = @import("shared").device.types.instance.Key;
const Node = @import("pulse").world.types.parse.syntax.Node;
const Preference = @import("pulse").devices.types.catalog.records.Preference;

pub fn read(allocator: std.mem.Allocator, bytes: []const u8) ![]const Preference {
    const nodes = try syntax.parse(allocator, bytes);
    var result: std.ArrayList(Preference) = .empty;
    for (nodes) |node| {
        if (node.Disabled) continue;
        const preference = try decode(node);
        if (preferred(result.items, preference.Device) != null) return error.DuplicateSelection;
        try result.append(allocator, preference);
    }
    return result.toOwnedSlice(allocator);
}

pub fn preferred(preferences: []const Preference, device: Key) ?[]const u8 {
    for (preferences) |selection| {
        if (selection.Device.Kind == device.Kind and selection.Device.Location == device.Location) return selection.Identity;
    }
    return null;
}

fn decode(node: Node) !Preference {
    if (node.Parent != null or !std.mem.eql(u8, node.Name, schema.SELECT) or node.Arguments.len != 2) return error.InvalidSelection;
    const device: Key = .{ .Kind = try parse.kind(node.Arguments[0]), .Location = try parse.number(node.Arguments[1]) };
    var identity: ?[]const u8 = null;
    for (node.Properties) |property| {
        if (!std.mem.eql(u8, property.Name, schema.BINARY) or !property.Value.Quoted or !unit.validIdentity(property.Value.Text)) return error.InvalidSelection;
        identity = property.Value.Text;
    }
    return .{ .Device = device, .Identity = identity orelse return error.InvalidSelection };
}
