//! Hikari Text Renderer

const framebuffer = @import("framebuffer.zig");
const font_mod = @import("font.zig");

pub const TextRenderer = struct {
    fb: *framebuffer.Framebuffer,
    font: *const font_mod.Font,
    cursor_x: u32,
    cursor_y: u32,
    fg_color: framebuffer.Color,
    bg_color: framebuffer.Color,
    columns: u32,
    rows: u32,

    pub fn initialize(
        fb: *framebuffer.Framebuffer,
        font: *const font_mod.Font,
    ) TextRenderer {
        return TextRenderer{
            .fb = fb,
            .font = font,
            .cursor_x = 0,
            .cursor_y = 0,
            .fg_color = framebuffer.Color.white,
            .bg_color = framebuffer.Color.black,
            .columns = fb.width / font.width,
            .rows = fb.height / font.height,
        };
    }

    pub fn set_colors(self: *TextRenderer, fg: framebuffer.Color, bg: framebuffer.Color) void {
        self.fg_color = fg;
        self.bg_color = bg;
    }

    pub fn set_cursor(self: *TextRenderer, col: u32, row: u32) void {
        self.cursor_x = col;
        self.cursor_y = row;
    }

    pub fn draw_char(self: *TextRenderer, codepoint: u32) void {
        const glyph = self.font.get_glyph(codepoint) orelse self.font.get_glyph('?') orelse return;

        const screen_x = self.cursor_x * self.font.width;
        const screen_y = self.cursor_y * self.font.height;

        var y: u32 = 0;
        while (y < self.font.height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.font.width) : (x += 1) {
                const pixel_on = self.font.get_glyph_pixel(glyph, x, y);
                const color = if (pixel_on) self.fg_color else self.bg_color;
                self.fb.put_pixel(screen_x + x, screen_y + y, color);
            }
        }
    }

    pub fn draw_char_at(self: *TextRenderer, codepoint: u32, col: u32, row: u32) void {
        const old_x = self.cursor_x;
        const old_y = self.cursor_y;
        self.cursor_x = col;
        self.cursor_y = row;
        self.draw_char(codepoint);
        self.cursor_x = old_x;
        self.cursor_y = old_y;
    }

    pub fn put_char(self: *TextRenderer, c: u8) void {
        switch (c) {
            '\n' => {
                self.cursor_x = 0;
                self.cursor_y += 1;
                if (self.cursor_y >= self.rows) {
                    self.scroll_up();
                    self.cursor_y = self.rows - 1;
                }
            },
            '\r' => {
                self.cursor_x = 0;
            },
            '\t' => {
                const tab_stop = 8;
                self.cursor_x = ((self.cursor_x / tab_stop) + 1) * tab_stop;
                if (self.cursor_x >= self.columns) {
                    self.cursor_x = 0;
                    self.cursor_y += 1;
                    if (self.cursor_y >= self.rows) {
                        self.scroll_up();
                        self.cursor_y = self.rows - 1;
                    }
                }
            },
            0x08 => {
                if (self.cursor_x > 0) {
                    self.cursor_x -= 1;
                }
            },
            else => {
                self.draw_char(c);
                self.cursor_x += 1;
                if (self.cursor_x >= self.columns) {
                    self.cursor_x = 0;
                    self.cursor_y += 1;
                    if (self.cursor_y >= self.rows) {
                        self.scroll_up();
                        self.cursor_y = self.rows - 1;
                    }
                }
            },
        }
    }

    pub fn print(self: *TextRenderer, str: []const u8) void {
        for (str) |c| {
            self.put_char(c);
        }
    }

    pub fn print_line(self: *TextRenderer, str: []const u8) void {
        self.print(str);
        self.put_char('\n');
    }

    pub fn scroll_up(self: *TextRenderer) void {
        const line_height = self.font.height;
        const scroll_pixels = (self.rows - 1) * line_height;

        self.fb.copy_rect(0, line_height, 0, 0, self.fb.width, scroll_pixels);

        self.fb.fill_rect(
            0,
            scroll_pixels,
            self.fb.width,
            line_height,
            self.bg_color,
        );
    }

    pub fn clear_screen(self: *TextRenderer) void {
        self.fb.clear(self.bg_color);
        self.cursor_x = 0;
        self.cursor_y = 0;
    }

    pub fn clear_line(self: *TextRenderer, row: u32) void {
        if (row >= self.rows) {
            return;
        }

        self.fb.fill_rect(
            0,
            row * self.font.height,
            self.fb.width,
            self.font.height,
            self.bg_color,
        );
    }

    pub fn print_u64(self: *TextRenderer, value: u64) void {
        var buf: [20]u8 = undefined;
        var i: usize = 0;
        var v = value;

        if (v == 0) {
            self.put_char('0');
            return;
        }

        while (v > 0) {
            buf[i] = @truncate((v % 10) + '0');
            v /= 10;
            i += 1;
        }

        while (i > 0) {
            i -= 1;
            self.put_char(buf[i]);
        }
    }

    pub fn print_hex(self: *TextRenderer, value: u64) void {
        const hex_chars = "0123456789ABCDEF";
        self.print("0x");

        var started = false;
        var shift: u6 = 60;
        while (true) {
            const nibble: u4 = @truncate((value >> shift) & 0xF);
            if (nibble != 0 or started or shift == 0) {
                self.put_char(hex_chars[nibble]);
                started = true;
            }
            if (shift == 0) break;
            shift -= 4;
        }
    }
};
