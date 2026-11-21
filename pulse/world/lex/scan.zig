//! Tokenize World Text Without Executing Type Annotations

const std = @import("std");

const grammar = @import("pulse").world.strings.grammar;
const space = @import("pulse").world.lex.space;
const string = @import("pulse").world.lex.string;

const State = @import("pulse").world.types.lex.state.State;
const Token = @import("pulse").world.types.lex.token.Token;
const WorldError = @import("pulse").world.errors.parse.document.WorldError;

pub fn peek(state: *State) WorldError!Token {
    if (state.Pending == null) state.Pending = try next(state);
    return state.Pending.?;
}

pub fn take(state: *State) WorldError!Token {
    if (state.Pending) |token| {
        state.Pending = null;
        return token;
    }
    return next(state);
}

fn next(state: *State) WorldError!Token {
    const previous = state.Offset;
    if (state.Offset == 0 and starts(state, grammar.BOM)) state.Offset += grammar.BOM.len;
    try trivia(state);
    if (state.Offset == state.Bytes.len) return .{ .Kind = .Eof };
    if (space.newline(try space.code(state.Bytes[state.Offset..]))) {
        state.Offset += try space.width(state.Bytes[state.Offset..]);
        return .{ .Kind = .End };
    }
    const separated = state.Offset != previous;
    const byte = state.Bytes[state.Offset];
    state.Offset += 1;
    var result: Token = try switch (byte) {
        '=', '{', '}', '(', ')', ';', '\n', '\r' => Token{ .Kind = switch (byte) {
            '=' => .Equal,
            '{' => .Open,
            '}' => .Close,
            '(' => .Annotation,
            ')' => .EndAnnotation,
            else => .End,
        } },
        '"' => string.read(state, 0),
        '#' => raw(state),
        '/' => if (state.Offset < state.Bytes.len and state.Bytes[state.Offset] == '-') omitted: {
            state.Offset += 1;
            break :omitted Token{ .Kind = .Omit };
        } else error.InvalidWorld,
        else => word(state),
    };
    result.Separated = separated;
    return result;
}

fn starts(state: *const State, text: []const u8) bool {
    return std.mem.startsWith(u8, state.Bytes[state.Offset..], text);
}

fn trivia(state: *State) WorldError!void {
    while (state.Offset < state.Bytes.len) {
        if (space.horizontal(try space.code(state.Bytes[state.Offset..]))) {
            state.Offset += try space.width(state.Bytes[state.Offset..]);
            continue;
        }
        switch (state.Bytes[state.Offset]) {
            '/' => {
                if (starts(state, grammar.LINE_COMMENT)) {
                    while (state.Offset < state.Bytes.len and state.Bytes[state.Offset] != '\n' and state.Bytes[state.Offset] != '\r') state.Offset += 1;
                } else if (starts(state, grammar.BLOCK_COMMENT)) {
                    var depth: usize = 1;
                    state.Offset += grammar.BLOCK_COMMENT.len;
                    while (depth != 0) {
                        if (state.Offset == state.Bytes.len) return error.InvalidWorld;
                        if (starts(state, grammar.BLOCK_COMMENT)) {
                            depth += 1;
                            state.Offset += grammar.BLOCK_COMMENT.len;
                        } else if (starts(state, grammar.BLOCK_END)) {
                            depth -= 1;
                            state.Offset += grammar.BLOCK_END.len;
                        } else state.Offset += 1;
                    }
                } else return;
            },
            '\\' => {
                state.Offset += 1;
                while (state.Offset < state.Bytes.len and (state.Bytes[state.Offset] == ' ' or state.Bytes[state.Offset] == '\t')) state.Offset += 1;
                if (state.Offset == state.Bytes.len or (state.Bytes[state.Offset] != '\n' and state.Bytes[state.Offset] != '\r')) return error.InvalidWorld;
                const newline = state.Bytes[state.Offset];
                state.Offset += 1;
                if (newline == '\r' and state.Offset < state.Bytes.len and state.Bytes[state.Offset] == '\n') state.Offset += 1;
            },
            else => return,
        }
    }
}

fn word(state: *State) WorldError!Token {
    const begin = state.Offset - 1;
    while (state.Offset < state.Bytes.len) {
        if (state.Bytes[state.Offset] >= 0xc0) {
            const character = try space.code(state.Bytes[state.Offset..]);
            if (space.horizontal(character) or space.newline(character)) break;
        }
        switch (state.Bytes[state.Offset]) {
            ' ', '\t', '\n', '\r', 0x0b, 0x0c, '=', '{', '}', '(', ')', ';', '/' => break,
            '"', '#', '\\' => return error.InvalidWorld,
            else => state.Offset += 1,
        }
    }
    const text = state.Bytes[begin..state.Offset];
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidWorld;
    for (text) |byte| if (byte < ' ') return error.InvalidWorld;
    return .{ .Kind = .Word, .Text = text };
}

fn raw(state: *State) WorldError!Token {
    var hashes: usize = 1;
    while (state.Offset < state.Bytes.len and state.Bytes[state.Offset] == '#') : (state.Offset += 1) hashes += 1;
    if (state.Offset == state.Bytes.len or state.Bytes[state.Offset] != '"') return error.InvalidWorld;
    state.Offset += 1;
    return string.read(state, hashes);
}
