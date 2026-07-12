//! AFS Allocation Operations

pub const AllocationError = error{
    OutOfSpace,
    InvalidCell,
};

pub const AllocationMap = struct {
    bitmap: []u8,
    total_cells: u32,
    next_free: u32,

    pub fn init(bitmap: []u8, total_cells: u32, first_data_cell: u32) AllocationMap {
        return AllocationMap{
            .bitmap = bitmap,
            .total_cells = total_cells,
            .next_free = first_data_cell,
        };
    }

    pub fn mark_allocated(self: *AllocationMap, cell: u32) void {
        if (cell >= self.total_cells) return;
        const byte_index = cell / 8;
        const bit_index: u3 = @intCast(cell % 8);
        self.bitmap[byte_index] |= @as(u8, 1) << bit_index;
    }

    pub fn mark_free(self: *AllocationMap, cell: u32) void {
        if (cell >= self.total_cells) return;
        const byte_index = cell / 8;
        const bit_index: u3 = @intCast(cell % 8);
        self.bitmap[byte_index] &= ~(@as(u8, 1) << bit_index);
    }

    pub fn is_allocated(self: *const AllocationMap, cell: u32) bool {
        if (cell >= self.total_cells) return true;
        const byte_index = cell / 8;
        const bit_index: u3 = @intCast(cell % 8);
        return (self.bitmap[byte_index] & (@as(u8, 1) << bit_index)) != 0;
    }

    pub fn allocate_cells(self: *AllocationMap, count: u32) AllocationError!u32 {
        if (count == 0) return self.next_free;

        const start = self.next_free;
        if (start + count > self.total_cells) {
            return AllocationError.OutOfSpace;
        }

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            self.mark_allocated(start + i);
        }

        self.next_free = start + count;
        return start;
    }

    pub fn reserve_range(self: *AllocationMap, start: u32, count: u32) void {
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            self.mark_allocated(start + i);
        }
    }

    pub fn free_count(self: *const AllocationMap) u32 {
        var count: u32 = 0;
        var i: u32 = 0;
        while (i < self.total_cells) : (i += 1) {
            if (!self.is_allocated(i)) {
                count += 1;
            }
        }
        return count;
    }
};

pub fn bitmap_size(total_cells: u32) u32 {
    return (total_cells + 7) / 8;
}
