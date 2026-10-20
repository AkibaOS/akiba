//! AFS Allocation Operations

const bits = @import("utils").bits;

pub fn bitmapSize(total_cells: u32) u32 {
    return @intCast(bits.operations.bitmapBytes(total_cells));
}
