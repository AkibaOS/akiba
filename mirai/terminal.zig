//! Terminal/Console Manager

const font = @import("graphics/font.zig");
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

pub fn init(fb: boot.FramebufferInfo) void {
    framebuffer = fb;
    cursor_x = 0;
    cursor_y = 0;

    // Get actual font dimensions
    char_width = font.get_width();
    char_height = font.get_height();

    // Debug output
    serial.print("Terminal init:\r\n");
    serial.print("  FB Width: ");
    serial.print_hex(fb.width);
    serial.print("\r\n  FB Pitch: ");
    serial.print_hex(fb.pitch);
    serial.print("\r\n  Pitch/4: ");
    serial.print_hex(fb.pitch / 4);
    serial.print("\r\n  Char Width: ");
    serial.print_hex(char_width);
    serial.print("\r\n  Chars per line: ");
    serial.print_hex(fb.width / char_width);
    serial.print("\r\n");

    // Clear screen
    video.init(fb);
    video.clear(BG_COLOR);

    // Draw header
    font.render_text("Akiba OS", 0, 10, fb, 0x00FF6B9D);
    font.render_text("Drifting from abyss towards the infinite!", 0, 30, fb, 0x00FFFFFF);

    // Position cursor below header
    cursor_y = 60;
}

pub fn put_char(char: u8) void {
    if (framebuffer == null) return;
    const fb = framebuffer.?;

    const max_x = (fb.pitch / 4); // Use actual scanline width

    switch (char) {
        '\n' => {
            cursor_x = 0;
            cursor_y += char_height;

            if (cursor_y + char_height >= fb.height) {
                scroll();
            }
        },
        '\x08' => {
            if (cursor_x >= char_width) {
                cursor_x -= char_width;
                clear_char_at_cursor();
            }
        },
        '\t' => {
            cursor_x += char_width * 4;
            if (cursor_x >= max_x) {
                cursor_x = 0;
                cursor_y += char_height;
                if (cursor_y + char_height >= fb.height) {
                    scroll();
                }
            }
        },
        else => {
            if (char >= 32 and char <= 126) {
                // Check if character will fit on current line using pitch
                if (cursor_x + char_width > max_x) {
                    cursor_x = 0;
                    cursor_y += char_height;

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
}
