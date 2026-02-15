//! Ash - Akiba Shell

const akiba = @import("akiba");

const MAX_INPUT = 256;
const MAX_ARGS = 16;

var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;
var char_buffer: [1]u8 = undefined;
var location_buffer: [256]u8 = undefined;
var letter_buffer: [256]u8 = undefined;

var arg_ptrs: [MAX_ARGS][*:0]const u8 = undefined;
var arg_storage: [MAX_ARGS][128]u8 = undefined;

const Color = struct {
    const white: u32 = 0x00FFFFFF;
    const green: u32 = 0x0088FF88;
    const red: u32 = 0x00FF4444;
};

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    while (true) {
        const location = akiba.io.getlocation(&location_buffer) catch "/";
        const stack_name = get_stack_name(location);

        _ = akiba.io.mark(akiba.io.stream, "(", Color.white) catch {};
        _ = akiba.io.mark(akiba.io.stream, stack_name, Color.green) catch {};
        _ = akiba.io.mark(akiba.io.stream, ") >>> ", Color.white) catch {};

        input_len = 0;
        while (true) {
            const char = akiba.io.getchar() catch continue;

            if (char == '\n') {
                _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch {};
                break;
            } else if (char == '\x08') {
                if (input_len > 0) {
                    input_len -= 1;
                    _ = akiba.io.mark(akiba.io.stream, "\x08", Color.white) catch {};
                }
            } else if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                char_buffer[0] = char;
                _ = akiba.io.mark(akiba.io.stream, &char_buffer, Color.white) catch {};
            }
        }

        if (input_len > 0) {
            execute_command(input_buffer[0..input_len]);
        }
    }

    return 0;
}

fn execute_command(input: []const u8) void {
    var argc: usize = 0;
    var i: usize = 0;

    while (i < input.len and argc < MAX_ARGS) {
        while (i < input.len and input[i] == ' ') : (i += 1) {}
        if (i >= input.len) break;

        const start = i;
        while (i < input.len and input[i] != ' ') : (i += 1) {}
        const end = i;

        if (end > start) {
            const arg_len = end - start;
            if (arg_len < 127) {
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

    const cmd = arg_storage[0][0..find_null(&arg_storage[0])];

    var path_buf: [512]u8 = undefined;

    const path = build_path(&path_buf, "/binaries/", cmd, ".akiba");
    if (try_spawn_with_args(path, arg_ptrs[0..argc])) {
        process_letters();
        return;
    }

    _ = akiba.io.mark(akiba.io.stream, "ash: binary not found: ", Color.red) catch {};
    _ = akiba.io.mark(akiba.io.stream, cmd, Color.white) catch {};
    _ = akiba.io.mark(akiba.io.stream, ".\n", Color.white) catch {};
}

fn try_spawn_with_args(path: []const u8, argv: [][*:0]const u8) bool {
    const pid = akiba.kata.spawn_with_args(path, argv) catch {
        return false;
    };

    _ = akiba.kata.wait(pid) catch {};

    return true;
}

fn process_letters() void {
    const letter_type = akiba.io.read_letter(&letter_buffer) catch return;

    if (letter_type == akiba.io.Letter.NAVIGATE) {
        var len: usize = 0;
        while (len < letter_buffer.len and letter_buffer[len] != 0) : (len += 1) {}

        if (len > 0) {
            akiba.io.setlocation(letter_buffer[0..len]) catch {};
        }
    }
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

fn get_stack_name(location: []const u8) []const u8 {
    // Root case
    if (location.len == 0 or (location.len == 1 and location[0] == '/')) {
        return "/";
    }

    // Find last '/' and return everything after it
    var last_slash: usize = 0;
    for (location, 0..) |c, i| {
        if (c == '/') {
            last_slash = i;
        }
    }

    // If path ends with '/', look for second-to-last slash
    if (last_slash == location.len - 1 and location.len > 1) {
        var i: usize = location.len - 2;
        while (i > 0) : (i -= 1) {
            if (location[i] == '/') {
                return location[i + 1 .. location.len - 1];
            }
        }
        return location[1 .. location.len - 1];
    }

    // Return part after last slash
    if (last_slash + 1 < location.len) {
        return location[last_slash + 1 ..];
    }

    return location;
}
