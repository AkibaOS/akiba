//! AFS Block I/O Interface

const errors = @import("shared").afs.errors;

const BlockError = errors.block.BlockError;

pub const BlockReader = struct {
    Context: *anyopaque,
    ReadFn: *const fn (context: *anyopaque, cell: u64, buffer: []u8) BlockError!void,
    CellSize: u32,
    TotalCells: u64,

    pub fn readCell(self: *const BlockReader, cell: u64, buffer: []u8) BlockError!void {
        if (cell >= self.TotalCells) {
            return BlockError.OutOfBounds;
        }
        if (self.CellSize == 0 or buffer.len < self.CellSize) {
            return BlockError.InvalidCell;
        }
        return self.ReadFn(self.Context, cell, buffer[0..self.CellSize]);
    }

    pub fn readCells(self: *const BlockReader, start_cell: u64, buffer: []u8) BlockError!void {
        if (self.CellSize == 0 or buffer.len % self.CellSize != 0) return BlockError.InvalidCell;
        const cells_to_read = buffer.len / self.CellSize;
        if (start_cell > self.TotalCells or cells_to_read > self.TotalCells - start_cell) return BlockError.OutOfBounds;
        var offset: usize = 0;
        var cell = start_cell;

        while (offset < buffer.len and cell < start_cell + cells_to_read) : ({
            offset += self.CellSize;
            cell += 1;
        }) {
            try self.readCell(cell, buffer[offset..][0..self.CellSize]);
        }
    }
};

pub const BlockWriter = struct {
    Context: *anyopaque,
    WriteFn: *const fn (context: *anyopaque, cell: u64, data: []const u8) BlockError!void,
    CellSize: u32,
    TotalCells: u64,

    pub fn writeCell(self: *const BlockWriter, cell: u64, data: []const u8) BlockError!void {
        if (cell >= self.TotalCells) {
            return BlockError.OutOfBounds;
        }
        if (self.CellSize == 0 or data.len < self.CellSize) {
            return BlockError.InvalidCell;
        }
        return self.WriteFn(self.Context, cell, data[0..self.CellSize]);
    }

    pub fn writeCells(self: *const BlockWriter, start_cell: u64, data: []const u8) BlockError!void {
        if (self.CellSize == 0 or data.len % self.CellSize != 0) return BlockError.InvalidCell;
        const cells_to_write = data.len / self.CellSize;
        if (start_cell > self.TotalCells or cells_to_write > self.TotalCells - start_cell) return BlockError.OutOfBounds;
        var offset: usize = 0;
        var cell = start_cell;

        while (offset < data.len and cell < start_cell + cells_to_write) : ({
            offset += self.CellSize;
            cell += 1;
        }) {
            try self.writeCell(cell, data[offset..][0..self.CellSize]);
        }
    }
};

pub const BlockDevice = struct {
    Reader: BlockReader,
    Writer: BlockWriter,

    pub fn readCell(self: *const BlockDevice, cell: u64, buffer: []u8) BlockError!void {
        return self.Reader.readCell(cell, buffer);
    }

    pub fn writeCell(self: *const BlockDevice, cell: u64, data: []const u8) BlockError!void {
        return self.Writer.writeCell(cell, data);
    }
};
