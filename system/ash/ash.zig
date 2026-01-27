//! Ash - Akiba Shell

const akiba = @import("akiba");

const MAX_INPUT = 256;
var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;
var char_buffer: [1]u8 = undefined; // Static buffer for single char echoing

export fn _start() noreturn {
    while (true) {
        // Print prompt
        _ = akiba.io.mark(akiba.io.stream, "/ >>> ", 0x00FFFFFF) catch {};

        // Read line
        input_len = 0;
        while (true) {
            const char = akiba.io.getchar() catch continue;

            if (char == '\n') {
                _ = akiba.io.mark(akiba.io.stream, "\n", 0x00FFFFFF) catch {};
                break;
            } else if (char == '\x08') {
                // Backspace
                if (input_len > 0) {
                    input_len -= 1;
                    // Echo backspace to screen
                    _ = akiba.io.mark(akiba.io.stream, "\x08", 0x00FFFFFF) catch {};
                }
            } else if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                // Echo character to screen
                char_buffer[0] = char;
                _ = akiba.io.mark(akiba.io.stream, &char_buffer, 0x00FFFFFF) catch {};
            }
        }

        // Parse and execute command
        if (input_len > 0) {
            execute_command(input_buffer[0..input_len]);
        }
    }
}

fn execute_command(input: []const u8) void {
    // Trim whitespace
    var start: usize = 0;
    while (start < input.len and input[start] == ' ') : (start += 1) {}

    var end: usize = input.len;
    while (end > start and input[end - 1] == ' ') : (end -= 1) {}

    if (start >= end) return;

    const trimmed = input[start..end];

    // Try to execute as binary
    var path_buf: [512]u8 = undefined;

    // First try with .akiba extension
    const path1 = build_path(&path_buf, "/binaries/", trimmed, ".akiba");
    if (try_spawn(path1)) return;

    // Then try without extension (in case user typed it)
    const path2 = build_path(&path_buf, "/binaries/", trimmed, "");
    if (try_spawn(path2)) return;

    // Binary not found
    _ = akiba.io.mark(akiba.io.stream, "ash: binary not found: ", 0x00FFFFFF) catch {};
    _ = akiba.io.mark(akiba.io.stream, trimmed, 0x00FFFFFF) catch {};
    _ = akiba.io.mark(akiba.io.stream, "\n", 0x00FFFFFF) catch {};
}

fn build_path(buf: []u8, prefix: []const u8, name: []const u8, suffix: []const u8) []const u8 {
    var pos: usize = 0;

    for (prefix) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    for (name) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    for (suffix) |c| {
        if (pos >= buf.len) break;
        buf[pos] = c;
        pos += 1;
    }

    return buf[0..pos];
}

fn try_spawn(path: []const u8) bool {
    const pid = akiba.kata.spawn(path) catch return false;
    _ = akiba.kata.wait(pid) catch return false;
    return true;
}
