//! Ash - Akiba Shell

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const kata = @import("kata");
const string = @import("string");
const sys = @import("sys");

const MAX_INPUT = 256;
const MAX_PARAMETERS = 16;

var input_buffer: [MAX_INPUT]u8 = undefined;
var input_len: usize = 0;
var char_buffer: [1]u8 = undefined;
var location_buffer: [256]u8 = undefined;
var letter_buffer: [256]u8 = undefined;

var param_ptrs: [MAX_PARAMETERS][*:0]const u8 = undefined;
var param_storage: [MAX_PARAMETERS][128]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    while (true) {
        const location = io.getlocation(&location_buffer) catch "/";
        const stack_name = string.getStackName(location);

        format.print("(");
        format.color(stack_name, colors.green);
        format.print(") >>> ");

        input_len = 0;
        while (true) {
            const char = io.getchar() catch continue;

            if (char == '\n') {
                format.print("\n");
                break;
            } else if (char == '\x08') {
                if (input_len > 0) {
                    input_len -= 1;
                    format.print("\x08");
                }
            } else if (char >= 32 and char <= 126 and input_len < MAX_INPUT - 1) {
                input_buffer[input_len] = char;
                input_len += 1;
                char_buffer[0] = char;
                format.print(&char_buffer);
            }
        }

        if (input_len > 0) {
            execute_command(input_buffer[0..input_len]);
        }
    }

    return 0;
}

fn execute_command(input: []const u8) void {
    var param_count: usize = 0;
    var i: usize = 0;

    while (i < input.len and param_count < MAX_PARAMETERS) {
        while (i < input.len and input[i] == ' ') : (i += 1) {}
        if (i >= input.len) break;

        const start = i;
        while (i < input.len and input[i] != ' ') : (i += 1) {}
        const end = i;

        if (end > start) {
            const param_len = end - start;
            if (param_len < 127) {
                for (input[start..end], 0..) |c, j| {
                    param_storage[param_count][j] = c;
                }
                param_storage[param_count][param_len] = 0;
                param_ptrs[param_count] = @ptrCast(&param_storage[param_count]);
                param_count += 1;
            }
        }
    }

    if (param_count == 0) return;

    const cmd = param_storage[0][0..string.findNull(&param_storage[0])];

    var location_buf: [512]u8 = undefined;
    const location = string.concat3(&location_buf, "/binaries/", cmd, ".akiba");

    if (try_spawn_with_params(location, param_ptrs[0..param_count])) {
        process_letters();
        return;
    }

    format.color("ash: binary not found: ", colors.red);
    format.print(cmd);
    format.println(".");
}

fn try_spawn_with_params(location: []const u8, params: [][*:0]const u8) bool {
    const pid = kata.spawnWithParams(location, params) catch {
        return false;
    };

    _ = kata.wait(pid) catch {};

    return true;
}

fn process_letters() void {
    const letter_type = io.readLetter(&letter_buffer) catch return;

    if (letter_type == io.Letter.NAVIGATE) {
        var len: usize = 0;
        while (len < letter_buffer.len and letter_buffer[len] != 0) : (len += 1) {}

        if (len > 0) {
            io.setlocation(letter_buffer[0..len]) catch {};
        }
    }
}
