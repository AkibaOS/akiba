//! AFS Allocation Map

const bits = @import("utils").bits;
const errors = @import("shared").afs.errors;

const AllocationError = errors.allocate.AllocationError;

pub const AllocationMap = struct {
    Bitmap: []u8,
    TotalCells: u32,
    NextFree: u32,

    pub fn init(bitmap: []u8, total_cells: u32, first_data_cell: u32) AllocationError!AllocationMap {
        const map = AllocationMap{
            .Bitmap = bitmap,
            .TotalCells = total_cells,
            .NextFree = first_data_cell,
        };
        try map.validateGeometry();
        return map;
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
        try self.validateGeometry();
        const start = self.NextFree;
        if (count > self.TotalCells - start) return AllocationError.OutOfSpace;
        var index: u32 = 0;
        while (index < count) : (index += 1) {
            if (self.isAllocated(start + index)) return AllocationError.OutOfSpace;
        }
        try self.reserveRange(start, count);
        self.NextFree = start + count;
        return start;
    }

    pub fn reserveRange(self: *AllocationMap, start: u32, count: u32) AllocationError!void {
        try self.validateGeometry();
        if (start > self.TotalCells or count > self.TotalCells - start) return AllocationError.InvalidCell;
        var index: u32 = 0;
        while (index < count) : (index += 1) {
            self.markAllocated(start + index);
        }
    }

    fn validateGeometry(self: *const AllocationMap) AllocationError!void {
        if (self.Bitmap.len < bits.operations.bitmapBytes(self.TotalCells)) return AllocationError.InvalidBitmap;
        if (self.NextFree > self.TotalCells) return AllocationError.InvalidCell;
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
