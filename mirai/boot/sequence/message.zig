//! Boot message buffering

const boot_limits = @import("../../common/limits/boot.zig");
const colors = @import("../../common/constants/colors.zig");
const serial = @import("../../drivers/serial/serial.zig");

var terminal_print_fn: ?*const fn ([]const u8) void = null;
var terminal_print_color_fn: ?*const fn ([]const u8, u32) void = null;

const Message = struct {
    text: [boot_limits.MAX_MESSAGE_LENGTH]u8,
    len: usize,
    color: u32,
    is_colored: bool,
};

var buffer: [boot_limits.MAX_BOOT_MESSAGES]Message = undefined;
var count: usize = 0;
var ready: bool = false;

pub fn set_terminal(
    print_fn: *const fn ([]const u8) void,
    print_color_fn: *const fn ([]const u8, u32) void,
) void {
    terminal_print_fn = print_fn;
    terminal_print_color_fn = print_color_fn;
    ready = true;
    replay();
}

pub fn is_ready() bool {
    return ready;
}

pub fn print(text: []const u8) void {
    write(text, colors.WHITE, false);
}

pub fn print_color(text: []const u8, color: u32) void {
    write(text, color, true);
}

fn write(text: []const u8, color: u32, is_colored: bool) void {
    serial.print(text);

    if (ready) {
        if (is_colored) {
            if (terminal_print_color_fn) |f| f(text, color);
        } else {
            if (terminal_print_fn) |f| f(text);
        }
    } else if (count < buffer.len) {
        var msg = &buffer[count];
        const len = @min(text.len, boot_limits.MAX_MESSAGE_LENGTH - 1);
        for (text[0..len], 0..) |c, i| {
            msg.text[i] = c;
        }
        msg.len = len;
        msg.color = color;
        msg.is_colored = is_colored;
        count += 1;
    }
}

fn replay() void {
    for (buffer[0..count]) |msg| {
        if (msg.is_colored) {
            if (terminal_print_color_fn) |f| f(msg.text[0..msg.len], msg.color);
        } else {
            if (terminal_print_fn) |f| f(msg.text[0..msg.len]);
        }
    }
    count = 0;
}
