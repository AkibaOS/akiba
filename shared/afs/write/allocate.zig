//! AFS Allocation Operations

const errors = @import("shared").afs.errors;

const bits = @import("utils").bits;

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
        bits.operations.setBit(self.Bitmap, cell);
    }

    pub fn markFree(self: *AllocationMap, cell: u32) void {
        if (cell >= self.TotalCells) return;
        bits.operations.clearBit(self.Bitmap, cell);
    }

    pub fn isAllocated(self: *const AllocationMap, cell: u32) bool {
        if (cell >= self.TotalCells) return true;
        return bits.operations.testBit(self.Bitmap, cell);
    }

    pub fn allocateCells(self: *AllocationMap, count: u32) AllocationError!u32 {
        if (count == 0) return self.NextFree;

        const start = self.NextFree;
        if (start + count > self.TotalCells) {
            return AllocationError.OutOfSpace;
        }

        self.reserveRange(start, count);

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
    return @intCast(bits.operations.bitmapBytes(total_cells));
}
