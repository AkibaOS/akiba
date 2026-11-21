//! Validate Pulse World Services Before Any Binary Starts

const std = @import("std");

const grammar = @import("pulse").world.strings.grammar;
const graph = @import("pulse").world.policy.graph;
const schema = @import("pulse").world.strings.schema;
const syntax = @import("pulse").world.parse.syntax;

const Document = @import("pulse").world.types.parse.document.Document;
const Job = @import("pulse").world.types.parse.document.Job;
const Node = @import("pulse").world.types.parse.syntax.Node;
const Value = @import("pulse").world.types.parse.syntax.Value;
const WorldError = @import("pulse").world.errors.parse.document.WorldError;

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) WorldError!Document {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const owned = arena.allocator();
    const input = try owned.dupe(u8, bytes);
    const nodes = try syntax.parse(owned, input);
    var jobs: std.ArrayList(Job) = .empty;
    for (nodes, 0..) |node, index| {
        if (node.Disabled or node.Parent != null) continue;
        try jobs.append(owned, try service(owned, nodes, index));
    }
    const result = try jobs.toOwnedSlice(owned);
    return .{ .Arena = arena, .Jobs = result, .Order = try graph.order(owned, result) };
}

fn service(allocator: std.mem.Allocator, nodes: []const Node, index: usize) WorldError!Job {
    const node = nodes[index];
    if (!std.mem.eql(u8, node.Name, schema.SERVICE) or node.Arguments.len != 1) return error.InvalidWorld;
    const name = try text(node.Arguments[0]);
    if (name.len == 0) return error.InvalidWorld;
    var dependencies: std.ArrayList([]const u8) = .empty;
    var result: Job = .{ .Name = name, .Binary = &.{}, .After = &.{} };
    for (node.Properties) |property| {
        if (std.mem.eql(u8, property.Name, schema.BINARY)) result.Binary = try text(property.Value) else if (std.mem.eql(u8, property.Name, schema.ENABLED)) {
            result.Enabled = try boolean(property.Value);
        } else if (std.mem.eql(u8, property.Name, schema.REQUIRED)) {
            result.Required = try boolean(property.Value);
        } else if (std.mem.eql(u8, property.Name, schema.CONTROL)) {
            result.Controller = try boolean(property.Value);
        } else if (std.mem.eql(u8, property.Name, schema.RESTART)) result.Restarts = try integer(allocator, property.Value) else if (std.mem.eql(u8, property.Name, schema.TIMEOUT)) {
            result.Timeout = try integer(allocator, property.Value);
            if (result.Timeout == 0) return error.InvalidWorld;
        } else return error.InvalidWorld;
    }
    if (!validBinary(result.Binary)) return error.InvalidWorld;
    for (nodes) |child| {
        if (child.Disabled or child.Parent != index) continue;
        if (child.Properties.len != 0) return error.InvalidWorld;
        if (std.mem.eql(u8, child.Name, schema.AFTER)) {
            if (child.Arguments.len == 0) return error.InvalidWorld;
            for (child.Arguments) |argument| try dependencies.append(allocator, try text(argument));
        } else if (std.mem.eql(u8, child.Name, schema.PARAMETERS) and child.Arguments.len == 1) {
            result.Parameters = try text(child.Arguments[0]);
        } else return error.InvalidWorld;
    }
    for (nodes) |child| {
        if (child.Disabled) continue;
        if (child.Parent) |parent| if (nodes[parent].Parent == index) return error.InvalidWorld;
    }
    result.After = try dependencies.toOwnedSlice(allocator);
    return result;
}

fn text(value: Value) WorldError![]const u8 {
    if (!value.Quoted) return error.InvalidWorld;
    return value.Text;
}

fn boolean(value: Value) WorldError!bool {
    if (value.Quoted) return error.InvalidWorld;
    if (std.mem.eql(u8, value.Text, grammar.TRUE)) return true;
    if (std.mem.eql(u8, value.Text, grammar.FALSE)) return false;
    return error.InvalidWorld;
}

fn integer(allocator: std.mem.Allocator, value: Value) WorldError!u64 {
    if (value.Quoted or value.Text.len == 0) return error.InvalidWorld;
    var digits: std.ArrayList(u8) = .empty;
    for (value.Text) |byte| if (byte != '_') try digits.append(allocator, byte);
    return std.fmt.parseInt(u64, digits.items, 0) catch error.InvalidWorld;
}

fn validBinary(name: []const u8) bool {
    if (name.len == 0 or (name.len <= 2 and std.mem.allEqual(u8, name, '.'))) return false;
    for (name) |byte| if (byte < ' ' or byte == '/' or byte == '\\') return false;
    return true;
}
