//! Coerce World Values Without Owning A Consumer Schema

const std = @import("std");

const grammar = @import("shared").world.strings.grammar;

const Node = @import("shared").world.types.parse.syntax.Node;
const SyntaxError = @import("shared").world.errors.syntax.SyntaxError;
const Value = @import("shared").world.types.parse.syntax.Value;

pub fn property(node: Node, key: []const u8) ?Value {
    var index = node.Properties.len;
    while (index != 0) {
        index -= 1;
        const candidate = node.Properties[index];
        if (std.mem.eql(u8, candidate.Name, key)) return candidate.Value;
    }
    return null;
}

pub fn text(value: Value) SyntaxError![]const u8 {
    if (!value.Quoted and (std.mem.eql(u8, value.Text, grammar.TRUE) or
        std.mem.eql(u8, value.Text, grammar.FALSE) or std.mem.eql(u8, value.Text, grammar.NULL))) return error.InvalidWorld;
    return value.Text;
}

pub fn unsigned(value: Value) SyntaxError!u64 {
    if (value.Quoted) return error.InvalidWorld;
    return std.fmt.parseInt(u64, value.Text, 0) catch error.InvalidWorld;
}

pub fn boolean(value: Value) SyntaxError!bool {
    if (value.Quoted) return error.InvalidWorld;
    if (std.mem.eql(u8, value.Text, grammar.TRUE)) return true;
    if (std.mem.eql(u8, value.Text, grammar.FALSE)) return false;
    return error.InvalidWorld;
}
