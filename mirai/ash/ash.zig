const terminal = @import("../terminal.zig");
const serial = @import("../drivers/serial.zig");
const afs = @import("../fs/afs.zig");

const mi = @import("commands/mi.zig");

const MAX_INPUT: usize = 256;
const MAX_ARGS: usize = 16;

var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;
var current_path: [256]u8 = undefined;
var current_path_len: usize = 1;
var current_cluster: u32 = 0;
var filesystem: ?*afs.AFS = null;

pub fn init(fs: *afs.AFS) void {
    filesystem = fs;
    current_cluster = fs.root_cluster;
    current_path[0] = '/';
    current_path_len = 1;

    show_prompt();
}

pub fn on_key_press(char: u8) void {
    switch (char) {
        '\n' => {
            terminal.put_char('\n');
            if (input_len > 0) {
                execute_command();
            }
            input_len = 0;
            show_prompt();
        },
        '\x08' => {
            if (input_len > 0) {
                input_len -= 1;
                terminal.put_char('\x08');
            }
        },
        else => {
            if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                terminal.put_char(char);
            }
        },
    }
}

fn show_prompt() void {
    const stack_name = get_current_stack_name();
    terminal.print(stack_name);
    terminal.print(" >>> ");
}

fn get_current_stack_name() []const u8 {
    if (current_path_len == 1) {
        return "/";
    }

    var i: usize = current_path_len - 1;
    while (i > 0) : (i -= 1) {
        if (current_path[i] == '/') {
            return current_path[i + 1 .. current_path_len];
        }
    }

    return current_path[0..current_path_len];
}

fn execute_command() void {
    const input = input_buffer[0..input_len];

    var args: [MAX_ARGS][]const u8 = undefined;
    var arg_count: usize = 0;

    var i: usize = 0;
    var arg_start: usize = 0;
    var in_arg = false;

    while (i <= input.len) : (i += 1) {
        const is_space = (i < input.len and input[i] == ' ');
        const is_end = (i == input.len);

        if (!in_arg and !is_space and !is_end) {
            arg_start = i;
            in_arg = true;
        } else if (in_arg and (is_space or is_end)) {
            if (arg_count < MAX_ARGS) {
                args[arg_count] = input[arg_start..i];
                arg_count += 1;
            }
            in_arg = false;
        }
    }

    if (arg_count == 0) return;

    const cmd = args[0];
    const cmd_args = args[1..arg_count];

    if (str_equal(cmd, "mi")) {
        if (filesystem) |fs| {
            mi.execute(fs, current_cluster, cmd_args);
        }
    } else if (str_equal(cmd, "wipe")) {
        terminal.clear_screen();
    } else {
        terminal.print("ash: command not found: ");
        terminal.print(cmd);
        terminal.put_char('\n');
    }
}

fn str_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |c, i| {
        if (c != b[i]) return false;
    }
    return true;
}
