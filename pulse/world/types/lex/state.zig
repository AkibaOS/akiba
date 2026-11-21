//! Owned World Lexical Cursor

const std = @import("std");

const Token = @import("pulse").world.types.lex.token.Token;

pub const State = struct {
    Allocator: std.mem.Allocator,
    Bytes: []const u8,
    Offset: usize = 0,
    Pending: ?Token = null,
};
