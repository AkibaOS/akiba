//! Hikari Text Renderer

const constants = @import("constants/constants.zig");
const framebuffer = @import("hikari").display.framebuffer;
const font = @import("hikari").display.font;
const strings = @import("strings/strings.zig");

pub const TextRenderer = struct {
    Framebuffer: *framebuffer.Framebuffer,
    Font: *const font.Font,
    CursorColumn: u32,
    CursorRow: u32,
    ForegroundColor: framebuffer.Color,
    BackgroundColor: framebuffer.Color,
    Columns: u32,
    Rows: u32,

    pub fn initialize(
        target: *framebuffer.Framebuffer,
        glyph_font: *const font.Font,
    ) TextRenderer {
        return TextRenderer{
            .Framebuffer = target,
            .Font = glyph_font,
            .CursorColumn = 0,
            .CursorRow = 0,
            .ForegroundColor = framebuffer.Color.WHITE,
            .BackgroundColor = framebuffer.Color.BLACK,
            .Columns = target.Width / glyph_font.Width,
            .Rows = target.Height / glyph_font.Height,
        };
    }

    pub fn setColors(self: *TextRenderer, foreground: framebuffer.Color, background: framebuffer.Color) void {
        self.ForegroundColor = foreground;
        self.BackgroundColor = background;
    }

    pub fn setCursor(self: *TextRenderer, column: u32, row: u32) void {
        self.CursorColumn = column;
        self.CursorRow = row;
    }

    pub fn drawChar(self: *TextRenderer, codepoint: u32) void {
        const glyph = self.Font.getGlyph(codepoint) orelse self.Font.getGlyph('?') orelse return;

        const screen_x = self.CursorColumn * self.Font.Width;
        const screen_y = self.CursorRow * self.Font.Height;

        var y: u32 = 0;
        while (y < self.Font.Height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.Font.Width) : (x += 1) {
                const pixel_on = self.Font.getGlyphPixel(glyph, x, y);
                const color = if (pixel_on) self.ForegroundColor else self.BackgroundColor;
                self.Framebuffer.putPixel(screen_x + x, screen_y + y, color);
            }
        }
    }

    pub fn drawCharAt(self: *TextRenderer, codepoint: u32, column: u32, row: u32) void {
        const previous_column = self.CursorColumn;
        const previous_row = self.CursorRow;
        self.CursorColumn = column;
        self.CursorRow = row;
        self.drawChar(codepoint);
        self.CursorColumn = previous_column;
        self.CursorRow = previous_row;
    }

    pub fn putChar(self: *TextRenderer, character: u8) void {
        switch (character) {
            '\n' => {
                self.CursorColumn = 0;
                self.advanceRow();
            },
            '\r' => {
                self.CursorColumn = 0;
            },
            '\t' => {
                self.CursorColumn = ((self.CursorColumn / constants.text.TAB_WIDTH) + 1) * constants.text.TAB_WIDTH;
                if (self.CursorColumn >= self.Columns) {
                    self.CursorColumn = 0;
                    self.advanceRow();
                }
            },
            constants.text.BACKSPACE => {
                if (self.CursorColumn > 0) {
                    self.CursorColumn -= 1;
                }
            },
            else => {
                self.drawChar(character);
                self.CursorColumn += 1;
                if (self.CursorColumn >= self.Columns) {
                    self.CursorColumn = 0;
                    self.advanceRow();
                }
            },
        }
    }

    fn advanceRow(self: *TextRenderer) void {
        self.CursorRow += 1;
        if (self.CursorRow >= self.Rows) {
            self.scrollUp();
            self.CursorRow = self.Rows - 1;
        }
    }

    pub fn print(self: *TextRenderer, text: []const u8) void {
        for (text) |character| {
            self.putChar(character);
        }
    }

    pub fn printLine(self: *TextRenderer, text: []const u8) void {
        self.print(text);
        self.putChar('\n');
    }

    pub fn scrollUp(self: *TextRenderer) void {
        const line_height = self.Font.Height;
        const scroll_pixels = (self.Rows - 1) * line_height;

        self.Framebuffer.copyRect(0, line_height, 0, 0, self.Framebuffer.Width, scroll_pixels);

        self.Framebuffer.fillRect(
            0,
            scroll_pixels,
            self.Framebuffer.Width,
            line_height,
            self.BackgroundColor,
        );
    }

    pub fn clearScreen(self: *TextRenderer) void {
        self.Framebuffer.clear(self.BackgroundColor);
        self.CursorColumn = 0;
        self.CursorRow = 0;
    }

    pub fn clearLine(self: *TextRenderer, row: u32) void {
        if (row >= self.Rows) {
            return;
        }

        self.Framebuffer.fillRect(
            0,
            row * self.Font.Height,
            self.Framebuffer.Width,
            self.Font.Height,
            self.BackgroundColor,
        );
    }

    pub fn printUnsigned(self: *TextRenderer, value: u64) void {
        var buffer: [constants.text.MAX_DIGITS]u8 = undefined;
        var length: usize = 0;
        var remaining = value;

        if (remaining == 0) {
            self.putChar('0');
            return;
        }

        while (remaining > 0) {
            buffer[length] = @truncate((remaining % constants.text.DECIMAL_BASE) + '0');
            remaining /= constants.text.DECIMAL_BASE;
            length += 1;
        }

        while (length > 0) {
            length -= 1;
            self.putChar(buffer[length]);
        }
    }

    pub fn printHex(self: *TextRenderer, value: u64) void {
        self.print("0x");

        var started = false;
        var shift: u6 = @bitSizeOf(u64) - constants.text.HEX_NIBBLE_BITS;
        while (true) {
            const nibble: u4 = @truncate((value >> shift) & constants.text.HEX_NIBBLE_MASK);
            if (nibble != 0 or started or shift == 0) {
                self.putChar(strings.text.HEX_DIGITS[nibble]);
                started = true;
            }
            if (shift == 0) break;
            shift -= constants.text.HEX_NIBBLE_BITS;
        }
    }
};
