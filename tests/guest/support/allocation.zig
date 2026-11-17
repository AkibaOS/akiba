//! Guest Physical Allocation Failure Budget

const common = @import("common");
const types = @import("tests").types.allocation;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Condition = types.Condition;

var remaining: ?usize = null;
var condition: ?Condition = null;

pub fn arm(successful: usize) void {
    condition = null;
    remaining = successful;
}

pub fn armWhen(predicate: Condition) void {
    remaining = null;
    condition = predicate;
}

pub fn clear() void {
    remaining = null;
    condition = null;
}

pub fn before() AllocationError!void {
    if (condition) |predicate| {
        if (predicate()) return AllocationError.OutOfMemory;
    }
    if (remaining) |*count| {
        if (count.* == 0) return AllocationError.OutOfMemory;
        count.* -= 1;
    }
}
