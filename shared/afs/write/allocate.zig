//! AFS Allocation Operations

const errors = @import("shared").afs.errors;

const AllocationError = errors.allocate.AllocationError;

pub const AllocationMap = struct {
    Bitmap: []u8,
    TotalCells: u32,
    NextFree: u32,

    pub fn init(bitmap: []u8, total_cells: u32, first_data_cell: u32) AllocationMap {
        return AllocationMap{
            .Bitmap = bitmap,
            .TotalCells = total_cells,
            .NextFree = first_data_cell,
        };
    }

    pub fn markAllocated(self: *AllocationMap, cell: u32) void {
        if (cell >= self.TotalCells) return;
        const byte_index = cell / @bitSizeOf(u8);
        const bit_index: u3 = @intCast(cell % @bitSizeOf(u8));
        self.Bitmap[byte_index] |= @as(u8, 1) << bit_index;
    }

    pub fn markFree(self: *AllocationMap, cell: u32) void {
        if (cell >= self.TotalCells) return;
        const byte_index = cell / @bitSizeOf(u8);
        const bit_index: u3 = @intCast(cell % @bitSizeOf(u8));
        self.Bitmap[byte_index] &= ~(@as(u8, 1) << bit_index);
    }

    pub fn isAllocated(self: *const AllocationMap, cell: u32) bool {
        if (cell >= self.TotalCells) return true;
        const byte_index = cell / @bitSizeOf(u8);
        const bit_index: u3 = @intCast(cell % @bitSizeOf(u8));
        return (self.Bitmap[byte_index] & (@as(u8, 1) << bit_index)) != 0;
    }

    pub fn allocateCells(self: *AllocationMap, count: u32) AllocationError!u32 {
        if (count == 0) return self.NextFree;

        const start = self.NextFree;
        if (start + count > self.TotalCells) {
            return AllocationError.OutOfSpace;
        }

        var index: u32 = 0;
        while (index < count) : (index += 1) {
            self.markAllocated(start + index);
        }

        self.NextFree = start + count;
        return start;
    }

    pub fn reserveRange(self: *AllocationMap, start: u32, count: u32) void {
        var index: u32 = 0;
        while (index < count) : (index += 1) {
            self.markAllocated(start + index);
        }
    }

    pub fn freeCount(self: *const AllocationMap) u32 {
        var count: u32 = 0;
        var index: u32 = 0;
        while (index < self.TotalCells) : (index += 1) {
            if (!self.isAllocated(index)) {
                count += 1;
            }
        }
        return count;
    }
};

pub fn bitmapSize(total_cells: u32) u32 {
    return (total_cells + @bitSizeOf(u8) - 1) / @bitSizeOf(u8);
}
