//! Character Console

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const typeset = @import("shared").typeset;

const draw = graphics.draw;

const Color = graphics.types.color.Color;
const Face = font.types.face.Face;
const Surface = graphics.types.surface.Surface;
const TextError = graphics.errors.text.TextError;
const TextRenderer = graphics.types.renderer.TextRenderer;

const constants = graphics.constants.console;

pub const Console = struct {
    Surface: *Surface,
    Face: *const Face,
    Renderer: *TextRenderer,
    PixelSize: i32,
    CellWidth: i32,
    CellHeight: i32,
    Baseline: i32,
    CursorColumn: u32,
    CursorRow: u32,
    Columns: u32,
    Rows: u32,
    ForegroundColor: Color,
    BackgroundColor: Color,

    pub fn initialize(
        surface: *Surface,
        face: *const Face,
        renderer: *TextRenderer,
        pixel_size: i32,
    ) TextError!Console {
        const reference = try font.charmap.lookup(face.Charmap, constants.REFERENCE_GLYPH);
        const advance = try font.metrics.advanceWidth(face, reference);
        const scale = face.scaleFor(pixel_size);

        const cell_width = @divTrunc(scale.applyToUnits(@intCast(advance)).Raw, constants.PIXEL_UNITS);
        const cell_height = face.lineHeight(pixel_size);

        return Console{
            .Surface = surface,
            .Face = face,
            .Renderer = renderer,
            .PixelSize = pixel_size,
            .CellWidth = if (cell_width > 0) cell_width else 1,
            .CellHeight = if (cell_height > 0) cell_height else 1,
            .Baseline = typeset.measure.ascent(face, pixel_size),
            .CursorColumn = 0,
            .CursorRow = 0,
            .Columns = @intCast(@divTrunc(@as(i32, @intCast(surface.Width)), if (cell_width > 0) cell_width else 1)),
            .Rows = @intCast(@divTrunc(@as(i32, @intCast(surface.Height)), if (cell_height > 0) cell_height else 1)),
            .ForegroundColor = graphics.types.color.WHITE,
            .BackgroundColor = graphics.types.color.BLACK,
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
                self.drawCell(character);
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
            @as(i32, @intCast(row)) * self.CellHeight,
            @intCast(self.Surface.Width),
            self.CellHeight,
            self.BackgroundColor,
        );
    }

    pub fn scrollUp(self: *Console) void {
        const scrolled: u32 = @intCast((self.Rows - 1) * @as(u32, @intCast(self.CellHeight)));

        draw.copyRect(self.Surface, 0, @intCast(self.CellHeight), 0, 0, self.Surface.Width, scrolled);
        draw.fillRect(
            self.Surface,
            0,
            @intCast(scrolled),
            @intCast(self.Surface.Width),
            self.CellHeight,
            self.BackgroundColor,
        );
    }

    fn drawCell(self: *Console, character: u8) void {
        const x = @as(i32, @intCast(self.CursorColumn)) * self.CellWidth;
        const y = @as(i32, @intCast(self.CursorRow)) * self.CellHeight;

        draw.fillRect(self.Surface, x, y, self.CellWidth, self.CellHeight, self.BackgroundColor);

        const glyph = [_]u8{character};
        graphics.text.drawString(
            self.Renderer,
            self.Surface,
            self.Face,
            .{ .PixelSize = self.PixelSize, .Tracking = 0 },
            x,
            y + self.Baseline,
            &glyph,
            self.ForegroundColor,
            self.BackgroundColor,
        ) catch {};
    }

    fn advanceRow(self: *Console) void {
        self.CursorRow += 1;
        if (self.CursorRow >= self.Rows) {
            self.scrollUp();
            self.CursorRow = self.Rows - 1;
        }
    }
};
