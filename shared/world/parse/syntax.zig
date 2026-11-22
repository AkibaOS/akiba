//! Parse World Nodes Without Recursive Stack Growth

const std = @import("std");

const scan = @import("shared").world.lex.scan;
const types = @import("shared").world.types.parse.syntax;

const Node = types.Node;
const Property = types.Property;
const State = @import("shared").world.types.lex.state.State;
const Value = types.Value;
const WorldError = @import("shared").world.errors.syntax.SyntaxError;

pub fn parse(arena: *std.heap.ArenaAllocator, bytes: []const u8) WorldError![]Node {
    const allocator = arena.allocator();
    const owned = try allocator.dupe(u8, bytes);
    var state: State = .{ .Allocator = allocator, .Bytes = owned };
    var nodes: std.ArrayList(Node) = .empty;
    var parents: std.ArrayList(usize) = .empty;
    while (true) {
        var token = try scan.peek(&state);
        switch (token.Kind) {
            .Eof => {
                if (parents.items.len != 0) return error.InvalidWorld;
                return nodes.toOwnedSlice(allocator);
            },
            .End => {
                _ = try scan.take(&state);
                continue;
            },
            .Close => {
                _ = try scan.take(&state);
                _ = parents.pop() orelse return error.InvalidWorld;
                continue;
            },
            else => {},
        }
        var disabled = false;
        if (token.Kind == .Omit) {
            _ = try scan.take(&state);
            disabled = true;
        }
        const label = try annotation(&state);
        token = try scan.take(&state);
        if (token.Kind != .Word and token.Kind != .String) return error.InvalidWorld;
        const name = token.Text;
        var arguments: std.ArrayList(Value) = .empty;
        var properties: std.ArrayList(Property) = .empty;
        var named = false;
        var block = false;
        while (true) {
            token = try scan.peek(&state);
            if (token.Kind == .Open) {
                _ = try scan.take(&state);
                block = true;
                break;
            }
            if (token.Kind == .Close or token.Kind == .Eof or token.Kind == .End) break;
            if (!token.Separated) return error.InvalidWorld;
            const omit = token.Kind == .Omit;
            if (omit) _ = try scan.take(&state);
            const value = try item(&state);
            if ((try scan.peek(&state)).Kind == .Equal) {
                _ = try scan.take(&state);
                const assigned = try item(&state);
                if (value.Annotation != null or value.Text.len == 0) return error.InvalidWorld;
                if (!omit) try properties.append(allocator, .{ .Name = value.Text, .Value = assigned });
                named = true;
            } else {
                if (named and !omit) return error.InvalidWorld;
                if (!omit) try arguments.append(allocator, value);
            }
        }
        const parent = if (parents.items.len == 0) null else parents.items[parents.items.len - 1];
        if (parent) |index| disabled = disabled or nodes.items[index].Disabled;
        const index = nodes.items.len;
        try nodes.append(allocator, .{
            .Name = name,
            .Annotation = label,
            .Parent = parent,
            .Arguments = try arguments.toOwnedSlice(allocator),
            .Properties = try properties.toOwnedSlice(allocator),
            .Disabled = disabled,
        });
        if (block) try parents.append(allocator, index);
    }
}

fn item(state: *State) WorldError!Value {
    const label = try annotation(state);
    const token = try scan.take(state);
    if (token.Kind != .Word and token.Kind != .String) return error.InvalidWorld;
    return .{ .Text = token.Text, .Quoted = token.Kind == .String, .Annotation = label };
}

fn annotation(state: *State) WorldError!?[]const u8 {
    if ((try scan.peek(state)).Kind != .Annotation) return null;
    _ = try scan.take(state);
    const label = try scan.take(state);
    if ((label.Kind != .String and label.Kind != .Word) or label.Text.len == 0 or
        (try scan.take(state)).Kind != .EndAnnotation) return error.InvalidWorld;
    return label.Text;
}
