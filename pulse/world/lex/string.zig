//! Decode Quoted And Raw World Strings With Multiline Indentation

const std = @import("std");

const State = @import("pulse").world.types.lex.state.State;
const Token = @import("pulse").world.types.lex.token.Token;
const WorldError = @import("pulse").world.errors.parse.document.WorldError;

pub fn read(state: *State, hashes: usize) WorldError!Token {
    const multiline = state.Bytes.len - state.Offset >= 2 and state.Bytes[state.Offset] == '"' and state.Bytes[state.Offset + 1] == '"';
    if (multiline) state.Offset += 2;
    const begin = state.Offset;
    while (state.Offset < state.Bytes.len) {
        const byte = state.Bytes[state.Offset];
        state.Offset += 1;
        if (byte == '\\' and hashes == 0) {
            if (state.Offset == state.Bytes.len) return error.InvalidWorld;
            if (std.ascii.isWhitespace(state.Bytes[state.Offset])) {
                while (state.Offset < state.Bytes.len and std.ascii.isWhitespace(state.Bytes[state.Offset])) state.Offset += 1;
            } else state.Offset += 1;
            continue;
        }
        if (!multiline and (byte == '\n' or byte == '\r')) return error.InvalidWorld;
        if (byte != '"') continue;
        const end = state.Offset - 1;
        var suffix = state.Offset;
        if (multiline) {
            if (state.Bytes.len - suffix < 2 or state.Bytes[suffix] != '"' or state.Bytes[suffix + 1] != '"') continue;
            suffix += 2;
        }
        var count: usize = 0;
        while (count < hashes and suffix + count < state.Bytes.len and state.Bytes[suffix + count] == '#') count += 1;
        if (count != hashes) continue;
        state.Offset = suffix + hashes;
        const raw = if (multiline) try dedent(state.Allocator, state.Bytes[begin..end]) else state.Bytes[begin..end];
        const text = if (hashes == 0) try decode(state.Allocator, raw) else try state.Allocator.dupe(u8, raw);
        if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidWorld;
        return .{ .Kind = .String, .Text = text };
    }
    return error.InvalidWorld;
}

fn dedent(allocator: std.mem.Allocator, source: []const u8) WorldError![]const u8 {
    if (source.len == 0 or (source[0] != '\r' and source[0] != '\n')) return error.InvalidWorld;
    const first: usize = if (source.len > 1 and source[0] == '\r' and source[1] == '\n') 2 else 1;
    const body = source[first..];
    var tail = body.len;
    while (tail != 0 and body[tail - 1] != '\n' and body[tail - 1] != '\r') tail -= 1;
    const indentation = body[tail..];
    for (indentation) |byte| if (byte != ' ' and byte != '\t') return error.InvalidWorld;
    const content = if (tail == 0) body[0..0] else body[0 .. tail - 1 - @as(usize, if (tail > 1 and body[tail - 1] == '\n' and body[tail - 2] == '\r') 1 else 0)];
    var output: std.ArrayList(u8) = .empty;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first_line = true;
    while (lines.next()) |raw| {
        const line = if (raw.len != 0 and raw[raw.len - 1] == '\r') raw[0 .. raw.len - 1] else raw;
        var skip: usize = 0;
        while (skip < line.len and (line[skip] == ' ' or line[skip] == '\t')) skip += 1;
        const text = if (skip == line.len) line[line.len..] else if (std.mem.startsWith(u8, line, indentation)) line[indentation.len..] else return error.InvalidWorld;
        if (!first_line) try output.append(allocator, '\n');
        first_line = false;
        try output.appendSlice(allocator, text);
    }
    return output.toOwnedSlice(allocator);
}

fn decode(allocator: std.mem.Allocator, bytes: []const u8) WorldError![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    var index: usize = 0;
    while (index < bytes.len) {
        const byte = bytes[index];
        index += 1;
        if (byte != '\\') {
            if (byte < ' ' and byte != '\t' and byte != '\n' and byte != '\r') return error.InvalidWorld;
            try output.append(allocator, byte);
            continue;
        }
        if (index == bytes.len) return error.InvalidWorld;
        const escape = bytes[index];
        index += 1;
        switch (escape) {
            'n' => try output.append(allocator, '\n'),
            'r' => try output.append(allocator, '\r'),
            't' => try output.append(allocator, '\t'),
            'b' => try output.append(allocator, 0x08),
            'f' => try output.append(allocator, 0x0c),
            's' => try output.append(allocator, ' '),
            '"', '\\', '/' => try output.append(allocator, escape),
            ' ', '\t', '\n', '\r' => while (index < bytes.len and std.ascii.isWhitespace(bytes[index])) : (index += 1) {},
            'u' => {
                if (index == bytes.len or bytes[index] != '{') return error.InvalidWorld;
                index += 1;
                const start = index;
                while (index < bytes.len and bytes[index] != '}') index += 1;
                if (index == bytes.len) return error.InvalidWorld;
                const value = std.fmt.parseInt(u21, bytes[start..index], 16) catch return error.InvalidWorld;
                index += 1;
                var encoded: [4]u8 = undefined;
                const length = std.unicode.utf8Encode(value, &encoded) catch return error.InvalidWorld;
                try output.appendSlice(allocator, encoded[0..length]);
            },
            else => return error.InvalidWorld,
        }
    }
    return output.toOwnedSlice(allocator);
}
