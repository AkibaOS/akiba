//! AFS Block I/O Interface

pub const BlockError = error{
    ReadFailed,
    WriteFailed,
    OutOfBounds,
    InvalidCell,
    DeviceError,
    NotSupported,
};

pub const BlockReader = struct {
    context: *anyopaque,
    read_fn: *const fn (context: *anyopaque, cell: u64, buffer: []u8) BlockError!void,
    cell_size: u32,
    total_cells: u64,

    pub fn read_cell(self: *const BlockReader, cell: u64, buffer: []u8) BlockError!void {
        if (cell >= self.total_cells) {
            return BlockError.OutOfBounds;
        }
        if (buffer.len < self.cell_size) {
            return BlockError.InvalidCell;
        }
        return self.read_fn(self.context, cell, buffer);
    }

    pub fn read_cells(self: *const BlockReader, start_cell: u64, buffer: []u8) BlockError!void {
        const cells_to_read = buffer.len / self.cell_size;
        var offset: usize = 0;
        var cell = start_cell;

        while (offset < buffer.len and cell < start_cell + cells_to_read) : ({
            offset += self.cell_size;
            cell += 1;
        }) {
            try self.read_cell(cell, buffer[offset..][0..self.cell_size]);
        }
    }
};

pub const BlockWriter = struct {
    context: *anyopaque,
    write_fn: *const fn (context: *anyopaque, cell: u64, data: []const u8) BlockError!void,
    cell_size: u32,
    total_cells: u64,

    pub fn write_cell(self: *const BlockWriter, cell: u64, data: []const u8) BlockError!void {
        if (cell >= self.total_cells) {
            return BlockError.OutOfBounds;
        }
        if (data.len < self.cell_size) {
            return BlockError.InvalidCell;
        }
        return self.write_fn(self.context, cell, data);
    }

    pub fn write_cells(self: *const BlockWriter, start_cell: u64, data: []const u8) BlockError!void {
        const cells_to_write = data.len / self.cell_size;
        var offset: usize = 0;
        var cell = start_cell;

        while (offset < data.len and cell < start_cell + cells_to_write) : ({
            offset += self.cell_size;
            cell += 1;
        }) {
            try self.write_cell(cell, data[offset..][0..self.cell_size]);
        }
    }
};

pub const BlockDevice = struct {
    reader: BlockReader,
    writer: BlockWriter,

    pub fn read_cell(self: *const BlockDevice, cell: u64, buffer: []u8) BlockError!void {
        return self.reader.read_cell(cell, buffer);
    }

    pub fn write_cell(self: *const BlockDevice, cell: u64, data: []const u8) BlockError!void {
        return self.writer.write_cell(cell, data);
    }
};
