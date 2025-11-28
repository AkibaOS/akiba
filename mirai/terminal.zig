//! Terminal/Console Manager

const font = @import("graphics/fonts/psf.zig");
const boot = @import("boot/multiboot2.zig");
const video = @import("graphics/video.zig");
const serial = @import("drivers/serial.zig");

var framebuffer: ?boot.FramebufferInfo = null;
var cursor_x: u32 = 0;
var cursor_y: u32 = 0;
var char_width: u32 = 8;
var char_height: u32 = 16;
const FG_COLOR: u32 = 0x00FFFFFF;
const BG_COLOR: u32 = 0x00000000;

// Track line types for proper backspace handling
const LineType = enum {
    Hard, // User pressed Enter
    Soft, // Auto-wrapped
};

const MAX_LINES = 100;
var line_types: [MAX_LINES]LineType = [_]LineType{.Hard} ** MAX_LINES;
var current_line: usize = 0;
var max_line_width: u32 = 0; // Actual usable width

pub fn init(fb: boot.FramebufferInfo) void {
    framebuffer = fb;
    cursor_x = 0;
    cursor_y = 0;

    // Get actual font dimensions (font already loaded in mirai.zig)
    char_width = font.get_width();
    char_height = font.get_height();

    // Calculate actual usable width (pitch/4 for u32 pixels)
    max_line_width = fb.pitch / 4;

    // Debug output
    serial.print("Terminal init:\n");
    serial.print("  FB Width: ");
    serial.print_hex(fb.width);
    serial.print("\n  FB Height: ");
    serial.print_hex(fb.height);
    serial.print("\n  FB Pitch: ");
    serial.print_hex(fb.pitch);
    serial.print("\n  Pitch/4: ");
    serial.print_hex(max_line_width);
    serial.print("\n  Char Width: ");
    serial.print_hex(char_width);
    serial.print("\n  Char Height: ");
    serial.print_hex(char_height);
    serial.print("\n  Chars per line: ");
    serial.print_hex(max_line_width / char_width);
    serial.print("\n");

    // Clear screen
    video.init(fb);
    video.clear(BG_COLOR);

    // Draw header
    font.render_text("Akiba OS", 10, 10, fb, 0x00FF6B9D);
    font.render_text("Drifting from abyss towards infinity", 10, 30, fb, 0x00FFFFFF);

    // Position cursor below header
    cursor_y = 60;
    current_line = get_line_number(cursor_y);

    // Initialize all lines as hard newlines
    var i: usize = 0;
    while (i < MAX_LINES) : (i += 1) {
        line_types[i] = .Hard;
    }
}

pub fn put_char(char: u8) void {
    if (framebuffer == null) return;
    const fb = framebuffer.?;

    switch (char) {
        '\n' => {
            cursor_x = 0;
            cursor_y += char_height;

            // Mark this as a HARD newline
            const old_line = current_line;
            current_line = get_line_number(cursor_y);
            if (current_line != old_line and current_line < MAX_LINES) {
                line_types[current_line] = .Hard;
            }

            if (cursor_y + char_height >= fb.height) {
                scroll();
            }
        },
        '\x08' => {
            // Backspace
            if (cursor_x >= char_width) {
                // Delete on same line
                cursor_x -= char_width;
                clear_char_at_cursor();
            } else if (cursor_x == 0 and cursor_y > 60) {
                // At start of line - check if we can go to previous line
                const current_line_num = get_line_number(cursor_y);
                if (current_line_num > 0 and current_line_num < MAX_LINES) {
                    // Only allow backspace if previous line was a SOFT wrap
                    if (line_types[current_line_num] == .Soft) {
                        // Go to end of previous line
                        cursor_y -= char_height;
                        current_line = get_line_number(cursor_y);

                        // Position at end of previous line (before wrap point)
                        // Use max_line_width, not fb.width
                        cursor_x = max_line_width - char_width;

                        // Align to character boundary
                        cursor_x = (cursor_x / char_width) * char_width;

                        clear_char_at_cursor();
                    }
                }
            }
        },
        '\t' => {
            cursor_x += char_width * 4;
            if (cursor_x >= max_line_width) {
                cursor_x = 0;
                cursor_y += char_height;

                // Mark as soft wrap
                const old_line = current_line;
                current_line = get_line_number(cursor_y);
                if (current_line != old_line and current_line < MAX_LINES) {
                    line_types[current_line] = .Soft;
                }

                if (cursor_y + char_height >= fb.height) {
                    scroll();
                }
            }
        },
        else => {
            if (char >= 32 and char <= 126) {
                // Check if character will fit on current line
                // Use max_line_width (pitch/4), not fb.width
                if (cursor_x + char_width > max_line_width) {
                    // Wrap to next line (SOFT wrap)
                    cursor_x = 0;
                    cursor_y += char_height;

                    const old_line = current_line;
                    current_line = get_line_number(cursor_y);
                    if (current_line != old_line and current_line < MAX_LINES) {
                        line_types[current_line] = .Soft;
                    }

                    if (cursor_y + char_height >= fb.height) {
                        scroll();
                    }
                }

                // Render character
                const text = [_]u8{char};
                font.render_text(&text, cursor_x, cursor_y, fb, FG_COLOR);

                cursor_x += char_width;
            }
        },
    }
}

pub fn print(text: []const u8) void {
    for (text) |char| {
        put_char(char);
    }
}

fn get_line_number(y: u32) usize {
    if (y < 60) return 0;
    return (y - 60) / char_height;
}

fn clear_char_at_cursor() void {
    if (framebuffer == null) return;
    const fb = framebuffer.?;

    const pixels = @as([*]volatile u32, @ptrFromInt(fb.addr));

    var row: u32 = 0;
    while (row < char_height) : (row += 1) {
        var col: u32 = 0;
        while (col < char_width) : (col += 1) {
            const px = cursor_x + col;
            const py = cursor_y + row;
            if (px < fb.width and py < fb.height) {
                const offset = py * (fb.pitch / 4) + px;
                pixels[offset] = BG_COLOR;
            }
        }
    }
}

fn scroll() void {
    if (framebuffer == null) return;
    const fb = framebuffer.?;

    const pixels = @as([*]volatile u32, @ptrFromInt(fb.addr));
    const pixels_per_line = fb.pitch / 4;

    var dst_y: u32 = 60;
    var src_y: u32 = 60 + char_height;

    while (src_y < fb.height) : ({
        src_y += 1;
        dst_y += 1;
    }) {
        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            const src_offset = src_y * pixels_per_line + x;
            const dst_offset = dst_y * pixels_per_line + x;
            pixels[dst_offset] = pixels[src_offset];
        }
    }

    var y: u32 = dst_y;
    while (y < fb.height) : (y += 1) {
        var x: u32 = 0;
        while (x < fb.width) : (x += 1) {
            const offset = y * pixels_per_line + x;
            pixels[offset] = BG_COLOR;
        }
    }

    cursor_y -= char_height;

    // Shift line types up
    var i: usize = 1;
    while (i < MAX_LINES) : (i += 1) {
        line_types[i - 1] = line_types[i];
    }
    line_types[MAX_LINES - 1] = .Hard;

    if (current_line > 0) current_line -= 1;
}

pub fn clear_screen() void {
    if (framebuffer == null) return;
    const fb = framebuffer.?;

    video.clear(BG_COLOR);

    // Redraw header
    font.render_text("Akiba OS", 10, 10, fb, 0x00FF6B9D);
    font.render_text("Drifting from abyss towards infinity", 10, 30, fb, 0x00FFFFFF);

    cursor_x = 0;
    cursor_y = 60;
    current_line = 0;

    // Reset line types
    var i: usize = 0;
    while (i < MAX_LINES) : (i += 1) {
        line_types[i] = .Hard;
    }
}
