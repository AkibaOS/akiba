//! Ash - Akiba Shell

const akiba = @import("akiba");

const MAX_INPUT = 256;
const MAX_ARGS = 16;

var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;
var char_buffer: [1]u8 = undefined;

// Argument parsing buffers
var arg_ptrs: [MAX_ARGS][*:0]const u8 = undefined;
var arg_storage: [MAX_ARGS][128]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

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
                if (input_len > 0) {
                    input_len -= 1;
                    _ = akiba.io.mark(akiba.io.stream, "\x08", 0x00FFFFFF) catch {};
                }
            } else if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                char_buffer[0] = char;
                _ = akiba.io.mark(akiba.io.stream, &char_buffer, 0x00FFFFFF) catch {};
            }
        }

        if (input_len > 0) {
            execute_command(input_buffer[0..input_len]);
        }
    }

    return 0;
}

fn execute_command(input: []const u8) void {
    // Parse input into arguments
    var argc: usize = 0;
    var i: usize = 0;

    while (i < input.len and argc < MAX_ARGS) {
        // Skip whitespace
        while (i < input.len and input[i] == ' ') : (i += 1) {}
        if (i >= input.len) break;

        // Find end of argument
        const start = i;
        while (i < input.len and input[i] != ' ') : (i += 1) {}
        const end = i;

        if (end > start) {
            const arg_len = end - start;
            if (arg_len < 127) {
                // Copy to storage with null terminator
                for (input[start..end], 0..) |c, j| {
                    arg_storage[argc][j] = c;
                }
                arg_storage[argc][arg_len] = 0;
                arg_ptrs[argc] = @ptrCast(&arg_storage[argc]);
                argc += 1;
            }
        }
    }

    if (argc == 0) return;

    // First argument is the command
    const cmd = arg_storage[0][0..find_null(&arg_storage[0])];

    // Build binary path
    var path_buf: [512]u8 = undefined;

    // Try with .akiba extension
    const path1 = build_path(&path_buf, "/binaries/", cmd, ".akiba");
    if (try_spawn_with_args(path1, arg_ptrs[0..argc])) return;

    // Try without extension
    const path2 = build_path(&path_buf, "/binaries/", cmd, "");
    if (try_spawn_with_args(path2, arg_ptrs[0..argc])) return;

    // Binary not found
    _ = akiba.io.mark(akiba.io.stream, "ash: binary not found: ", 0x00FFFFFF) catch {};
    _ = akiba.io.mark(akiba.io.stream, cmd, 0x00FFFFFF) catch {};
    _ = akiba.io.mark(akiba.io.stream, "\n", 0x00FFFFFF) catch {};
}

fn find_null(buf: []const u8) usize {
    var len: usize = 0;
    while (len < buf.len and buf[len] != 0) : (len += 1) {}
    return len;
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

fn try_spawn_with_args(path: []const u8, argv: [][*:0]const u8) bool {
    const pid = akiba.kata.spawn_with_args(path, argv) catch return false;
    _ = akiba.kata.wait(pid) catch return false;
    return true;
}
