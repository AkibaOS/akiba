//! Guest Physical Allocation Failure Budget

const common = @import("common");

const AllocationError = common.errors.memory.allocation.AllocationError;

var remaining: ?usize = null;

pub fn arm(successful: usize) void {
    remaining = successful;
}

pub fn clear() void {
    remaining = null;
}

pub fn before() AllocationError!void {
    if (remaining) |*count| {
        if (count.* == 0) return AllocationError.OutOfMemory;
        count.* -= 1;
    }
}
