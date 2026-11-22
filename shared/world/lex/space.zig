//! Classify World Unicode Whitespace And Newlines

const std = @import("std");

const WorldError = @import("shared").world.errors.syntax.SyntaxError;

pub fn code(bytes: []const u8) WorldError!u21 {
    if (bytes.len == 0) return error.InvalidWorld;
    const length = std.unicode.utf8ByteSequenceLength(bytes[0]) catch return error.InvalidWorld;
    if (length > bytes.len) return error.InvalidWorld;
    return std.unicode.utf8Decode(bytes[0..length]) catch error.InvalidWorld;
}

pub fn width(bytes: []const u8) WorldError!usize {
    if (bytes.len == 0) return error.InvalidWorld;
    const length = std.unicode.utf8ByteSequenceLength(bytes[0]) catch return error.InvalidWorld;
    if (length > bytes.len) return error.InvalidWorld;
    return length;
}

pub fn horizontal(character: u21) bool {
    return switch (character) {
        '\t', ' ', 0x00a0, 0x1680, 0x2000...0x200a, 0x202f, 0x205f, 0x3000 => true,
        else => false,
    };
}

pub fn newline(character: u21) bool {
    return switch (character) {
        '\n', '\r', 0x000c, 0x0085, 0x2028, 0x2029 => true,
        else => false,
    };
}
