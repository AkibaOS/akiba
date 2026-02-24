//! Terminal - Console output with cursor and scrolling

const ascii = @import("../../common/constants/ascii.zig");
const boot = @import("../../boot/multiboot/multiboot.zig");
const colors = @import("../../common/constants/colors.zig");
const font = @import("../fonts/psf.zig");
const pixel = @import("../../utils/graphics/pixel.zig");
const terminal_limits = @import("../../common/limits/terminal.zig");
const video = @import("../video/video.zig");

const LineType = enum { Hard, Soft };

var fb: ?boot.FramebufferInfo = null;
var cursor_x: u32 = 0;
var cursor_y: u32 = 0;
var char_width: u32 = terminal_limits.DEFAULT_CHAR_WIDTH;
var char_height: u32 = terminal_limits.DEFAULT_CHAR_HEIGHT;
var max_line_width: u32 = 0;
var line_types: [terminal_limits.MAX_LINES]LineType = [_]LineType{.Hard} ** terminal_limits.MAX_LINES;
var current_line: usize = 0;

pub fn init(framebuffer: boot.FramebufferInfo) void {
    fb = framebuffer;
    cursor_x = 0;
    cursor_y = 0;
    current_line = 0;

    char_width = font.get_width();
    char_height = font.get_height();
    max_line_width = pixel.line_width(framebuffer);

    video.init(framebuffer);
    video.clear(colors.BLACK);

    reset_line_types();
}

fn reset_line_types() void {
    for (&line_types) |*lt| {
        lt.* = .Hard;
    }
}

pub fn put_char(char: u8) void {
    put_char_color(char, colors.WHITE);
}

pub fn put_char_color(char: u8, color: u32) void {
    const f = fb orelse return;

    switch (char) {
        ascii.NEWLINE => handle_newline(f),
        ascii.BACKSPACE => handle_backspace(f),
        ascii.TAB => handle_tab(f),
        else => handle_printable(f, char, color),
    }
}

fn handle_newline(f: boot.FramebufferInfo) void {
    cursor_x = 0;
    cursor_y += char_height;
    mark_line(.Hard);
    check_scroll(f);
}

fn handle_backspace(f: boot.FramebufferInfo) void {
    if (cursor_x >= char_width) {
        cursor_x -= char_width;
        clear_char_at_cursor(f);
    } else if (cursor_x == 0 and cursor_y > 0) {
        const line_num = cursor_y / char_height;
        if (line_num > 0 and line_num < terminal_limits.MAX_LINES) {
            if (line_types[line_num] == .Soft) {
                cursor_y -= char_height;
                current_line = cursor_y / char_height;
                cursor_x = ((max_line_width - char_width) / char_width) * char_width;
                clear_char_at_cursor(f);
            }
        }
    }
}

fn handle_tab(f: boot.FramebufferInfo) void {
    cursor_x += char_width * terminal_limits.TAB_WIDTH;
    if (cursor_x >= max_line_width) {
        cursor_x = 0;
        cursor_y += char_height;
        mark_line(.Soft);
        check_scroll(f);
    }
}

fn handle_printable(f: boot.FramebufferInfo, char: u8, color: u32) void {
    if (char < ascii.PRINTABLE_START or char > ascii.PRINTABLE_END) return;

    if (cursor_x + char_width > max_line_width) {
        cursor_x = 0;
        cursor_y += char_height;
        mark_line(.Soft);
        check_scroll(f);
    }

    font.render_char(char, cursor_x, cursor_y, f, color);
    cursor_x += char_width;
}

fn mark_line(line_type: LineType) void {
    const new_line = cursor_y / char_height;
    if (new_line != current_line and new_line < terminal_limits.MAX_LINES) {
        line_types[new_line] = line_type;
    }
    current_line = new_line;
}

fn check_scroll(f: boot.FramebufferInfo) void {
    if (cursor_y + char_height >= f.height) {
        scroll(f);
    }
}

fn clear_char_at_cursor(f: boot.FramebufferInfo) void {
    pixel.fill_rect(f, cursor_x, cursor_y, char_width, char_height, colors.BLACK);
}

fn scroll(f: boot.FramebufferInfo) void {
    var dst_y: u32 = 0;
    var src_y: u32 = char_height;

    while (src_y < f.height) : ({
        src_y += 1;
        dst_y += 1;
    }) {
        pixel.copy_row(f, dst_y, src_y);
    }

    while (dst_y < f.height) : (dst_y += 1) {
        pixel.clear_row(f, dst_y, colors.BLACK);
    }

    cursor_y -= char_height;

    var i: usize = 1;
    while (i < terminal_limits.MAX_LINES) : (i += 1) {
        line_types[i - 1] = line_types[i];
    }
    line_types[terminal_limits.MAX_LINES - 1] = .Hard;

    if (current_line > 0) current_line -= 1;
}

pub fn print(text: []const u8) void {
    for (text) |char| {
        put_char(char);
    }
}

pub fn print_color(text: []const u8, color: u32) void {
    for (text) |char| {
        put_char_color(char, color);
    }
}

pub fn clear_screen() void {
    const f = fb orelse return;

    pixel.fill(f, colors.BLACK);
    cursor_x = 0;
    cursor_y = 0;
    current_line = 0;
    reset_line_types();
}

pub fn get_cursor_x() u32 {
    return cursor_x;
}

pub fn get_cursor_y() u32 {
    return cursor_y;
}

pub fn set_cursor(x: u32, y: u32) void {
    cursor_x = x;
    cursor_y = y;
}
