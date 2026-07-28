//! Character Console

const graphics = @import("shared").graphics;

const draw = graphics.draw;

const format = @import("utils").format;

const Color = graphics.types.color.Color;
const Font = graphics.types.font.Font;
const Surface = graphics.types.surface.Surface;

const constants = graphics.constants.console;
const limits = format.constants.format;

pub const Console = struct {
    Surface: *Surface,
    Font: *const Font,
    CursorColumn: u32,
    CursorRow: u32,
    ForegroundColor: Color,
    BackgroundColor: Color,
    Columns: u32,
    Rows: u32,

    pub fn initialize(target: *Surface, glyph_font: *const Font) Console {
        return Console{
            .Surface = target,
            .Font = glyph_font,
            .CursorColumn = 0,
            .CursorRow = 0,
            .ForegroundColor = graphics.types.color.WHITE,
            .BackgroundColor = graphics.types.color.BLACK,
            .Columns = target.Width / glyph_font.Width,
            .Rows = target.Height / glyph_font.Height,
        };
    }

    pub fn setColors(self: *Console, foreground: Color, background: Color) void {
        self.ForegroundColor = foreground;
        self.BackgroundColor = background;
    }

    pub fn setCursor(self: *Console, column: u32, row: u32) void {
        self.CursorColumn = column;
        self.CursorRow = row;
    }

    pub fn drawChar(self: *Console, codepoint: u32) void {
        const glyph = self.Font.getGlyph(codepoint) orelse self.Font.getGlyph('?') orelse return;

        const screen_x: i32 = @intCast(self.CursorColumn * self.Font.Width);
        const screen_y: i32 = @intCast(self.CursorRow * self.Font.Height);

        var y: u32 = 0;
        while (y < self.Font.Height) : (y += 1) {
            var x: u32 = 0;
            while (x < self.Font.Width) : (x += 1) {
                const lit = self.Font.isGlyphPixelSet(glyph, x, y);
                const color = if (lit) self.ForegroundColor else self.BackgroundColor;
                draw.putPixel(self.Surface, screen_x + @as(i32, @intCast(x)), screen_y + @as(i32, @intCast(y)), color);
            }
        }
    }

    pub fn drawCharAt(self: *Console, codepoint: u32, column: u32, row: u32) void {
        const previous_column = self.CursorColumn;
        const previous_row = self.CursorRow;
        self.CursorColumn = column;
        self.CursorRow = row;
        self.drawChar(codepoint);
        self.CursorColumn = previous_column;
        self.CursorRow = previous_row;
    }

    pub fn putChar(self: *Console, character: u8) void {
        switch (character) {
            '\n' => {
                self.CursorColumn = 0;
                self.advanceRow();
            },
            '\r' => {
                self.CursorColumn = 0;
            },
            '\t' => {
                self.CursorColumn = ((self.CursorColumn / constants.TAB_WIDTH) + 1) * constants.TAB_WIDTH;
                if (self.CursorColumn >= self.Columns) {
                    self.CursorColumn = 0;
                    self.advanceRow();
                }
            },
            constants.BACKSPACE => {
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

    pub fn print(self: *Console, message: []const u8) void {
        for (message) |character| {
            self.putChar(character);
        }
    }

    pub fn printLine(self: *Console, message: []const u8) void {
        self.print(message);
        self.putChar('\n');
    }

    pub fn printUnsigned(self: *Console, value: u64) void {
        var digits: [limits.MAX_DECIMAL_DIGITS]u8 = undefined;
        self.print(format.number.decimal(value, &digits));
    }

    pub fn printHex(self: *Console, value: u64) void {
        self.print("0x");
        var digits: [limits.MAX_HEX_DIGITS]u8 = undefined;
        self.print(format.number.hexUpper(value, &digits));
    }

    pub fn scrollUp(self: *Console) void {
        const line_height = self.Font.Height;
        const scrolled = (self.Rows - 1) * line_height;

        draw.copyRect(self.Surface, 0, line_height, 0, 0, self.Surface.Width, scrolled);
        draw.fillRect(
            self.Surface,
            0,
            @intCast(scrolled),
            @intCast(self.Surface.Width),
            @intCast(line_height),
            self.BackgroundColor,
        );
    }

    pub fn clearScreen(self: *Console) void {
        draw.clear(self.Surface, self.BackgroundColor);
        self.CursorColumn = 0;
        self.CursorRow = 0;
    }

    pub fn clearLine(self: *Console, row: u32) void {
        if (row >= self.Rows) {
            return;
        }
        draw.fillRect(
            self.Surface,
            0,
            @intCast(row * self.Font.Height),
            @intCast(self.Surface.Width),
            @intCast(self.Font.Height),
            self.BackgroundColor,
        );
    }

    fn advanceRow(self: *Console) void {
        self.CursorRow += 1;
        if (self.CursorRow >= self.Rows) {
            self.scrollUp();
            self.CursorRow = self.Rows - 1;
        }
    }
};
