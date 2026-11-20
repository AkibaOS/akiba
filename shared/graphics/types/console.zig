//! Character Console

const std = @import("std");

const font = @import("shared").font;
const graphics = @import("shared").graphics;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const draw = graphics.draw;

const Color = graphics.types.color.Color;
const CoordinateError = raster.errors.raster.CoordinateError;
const Face = font.types.face.font.Face;
const FontError = font.errors.font.FontError;
const Surface = graphics.types.surface.Surface;
const TextError = graphics.errors.text.rendering.TextError;
const TextRenderer = graphics.types.renderer.TextRenderer;

const constants = graphics.constants.console;
const palette = graphics.constants.palette;

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
        if (surface.Width > std.math.maxInt(i32) or surface.Height > std.math.maxInt(i32)) {
            return CoordinateError.CoordinateOutOfRange;
        }

        const scale = try face.scaleFor(pixel_size);
        const reference = try font.charmap.lookupFace(face, constants.REFERENCE_GLYPH);
        const advance = try font.metrics.advanceWidth(face, reference);
        const width = @divTrunc(scale.applyToUnitsRawWide(advance), constants.PIXEL_UNITS);
        const cell_width = std.math.cast(i32, @max(width, 1)) orelse return FontError.MetricOutOfRange;
        const cell_height = @max(try face.lineHeight(pixel_size), 1);

        return Console{
            .Surface = surface,
            .Face = face,
            .Renderer = renderer,
            .PixelSize = pixel_size,
            .CellWidth = cell_width,
            .CellHeight = cell_height,
            .Baseline = try typeset.measure.ascent(face, pixel_size),
            .CursorColumn = 0,
            .CursorRow = 0,
            .Columns = surface.Width / @as(u32, @intCast(cell_width)),
            .Rows = surface.Height / @as(u32, @intCast(cell_height)),
            .ForegroundColor = palette.WHITE,
            .BackgroundColor = palette.BLACK,
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
        if (self.Columns == 0 or self.Rows == 0) return;

        switch (character) {
            '\n' => {
                self.CursorColumn = 0;
                self.advanceRow();
            },
            '\r' => {
                self.CursorColumn = 0;
            },
            '\t' => {
                const next_tab = ((@as(u64, self.CursorColumn) / constants.TAB_WIDTH) + 1) * constants.TAB_WIDTH;
                if (next_tab >= self.Columns) {
                    self.CursorColumn = 0;
                    self.advanceRow();
                } else {
                    self.CursorColumn = @intCast(next_tab);
                }
            },
            constants.BACKSPACE => {
                if (self.CursorColumn > 0) {
                    self.CursorColumn -= 1;
                }
            },
            else => {
                self.drawCell(character);
                if (self.CursorColumn >= self.Columns - 1) {
                    self.CursorColumn = 0;
                    self.advanceRow();
                } else {
                    self.CursorColumn += 1;
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
        if (self.Rows == 0) return;
        const scrolled = (self.Rows - 1) * @as(u32, @intCast(self.CellHeight));

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
        if (self.CursorColumn >= self.Columns or self.CursorRow >= self.Rows) return;
        const x = @as(i32, @intCast(self.CursorColumn)) * self.CellWidth;
        const y = @as(i32, @intCast(self.CursorRow)) * self.CellHeight;

        draw.fillRect(self.Surface, x, y, self.CellWidth, self.CellHeight, self.BackgroundColor);

        const baseline = std.math.cast(i32, @as(i64, y) + self.Baseline) orelse return;
        const glyph = [_]u8{character};
        graphics.text.drawString(
            self.Renderer,
            self.Surface,
            self.Face,
            .{ .PixelSize = self.PixelSize, .Tracking = 0 },
            x,
            baseline,
            &glyph,
            self.ForegroundColor,
            self.BackgroundColor,
        ) catch {};
    }

    fn advanceRow(self: *Console) void {
        if (self.Rows == 0) return;
        if (self.CursorRow >= self.Rows - 1) {
            self.scrollUp();
            self.CursorRow = self.Rows - 1;
        } else {
            self.CursorRow += 1;
        }
    }
};
