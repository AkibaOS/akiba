//! Table formatting

const io = @import("io");
const colors = @import("colors");

pub const Alignment = enum {
    left,
    right,
};

pub const Column = struct {
    name: []const u8,
    color: u32 = colors.white,
    alignment: Alignment = .left,
};

const MAX_COLUMNS = 8;
const MAX_ROWS = 256;

pub const Table = struct {
    columns: []const Column,
    col_widths: [MAX_COLUMNS]usize,
    rows: [MAX_ROWS][MAX_COLUMNS][]const u8,
    row_colors: [MAX_ROWS][MAX_COLUMNS]u32,
    row_count: usize,

    pub fn init(cols: []const Column) Table {
        var t = Table{
            .columns = cols,
            .col_widths = [_]usize{0} ** MAX_COLUMNS,
            .rows = undefined,
            .row_colors = undefined,
            .row_count = 0,
        };

        for (cols, 0..) |col, i| {
            t.col_widths[i] = col.name.len;
        }

        return t;
    }

    pub fn row(self: *Table, cells: []const []const u8) void {
        self.rowColored(cells, null);
    }

    pub fn rowColored(self: *Table, cells: []const []const u8, cell_colors: ?[]const u32) void {
        if (self.row_count >= MAX_ROWS) return;

        for (cells, 0..) |cell, i| {
            if (i >= self.columns.len) break;
            self.rows[self.row_count][i] = cell;

            if (cell_colors) |cc| {
                self.row_colors[self.row_count][i] = cc[i];
            } else {
                self.row_colors[self.row_count][i] = self.columns[i].color;
            }

            if (cell.len > self.col_widths[i]) {
                self.col_widths[i] = cell.len;
            }
        }

        self.row_count += 1;
    }

    pub fn print(self: *Table) void {
        for (self.columns, 0..) |col, i| {
            _ = io.mark(io.stream, col.name, colors.white) catch {};
            self.printPadding(self.col_widths[i] - col.name.len + 2);
        }
        _ = io.mark(io.stream, "\n", colors.white) catch {};

        for (0..self.row_count) |r| {
            for (0..self.columns.len) |c| {
                const cell = self.rows[r][c];
                const col = self.columns[c];
                const color = self.row_colors[r][c];

                if (col.alignment == .right) {
                    self.printPadding(self.col_widths[c] - cell.len);
                    _ = io.mark(io.stream, cell, color) catch {};
                    self.printPadding(2);
                } else {
                    _ = io.mark(io.stream, cell, color) catch {};
                    self.printPadding(self.col_widths[c] - cell.len + 2);
                }
            }
            _ = io.mark(io.stream, "\n", colors.white) catch {};
        }
    }

    fn printPadding(self: *Table, count: usize) void {
        _ = self;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            _ = io.mark(io.stream, " ", colors.white) catch {};
        }
    }
};
