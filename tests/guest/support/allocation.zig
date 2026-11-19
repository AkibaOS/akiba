//! Guest Physical Allocation Failure Budget

const common = @import("common");
const types = @import("tests").guest.types.allocation;

const AllocationError = common.errors.memory.allocation.AllocationError;
const Condition = types.Condition;

var remaining: ?usize = null;
var condition: ?Condition = null;
var observed: ?usize = null;

pub fn arm(successful: usize) void {
    clear();
    remaining = successful;
}

pub fn armWhen(predicate: Condition) void {
    clear();
    condition = predicate;
}

pub fn measure() void {
    clear();
    observed = 0;
}

pub fn measured() ?usize {
    const count = observed;
    observed = null;
    return count;
}

pub fn clear() void {
    remaining = null;
    condition = null;
    observed = null;
}

pub fn before() AllocationError!void {
    if (observed) |*count| count.* += 1;
    if (condition) |predicate| {
        if (predicate()) return AllocationError.OutOfMemory;
    }
    if (remaining) |*count| {
        if (count.* == 0) return AllocationError.OutOfMemory;
        count.* -= 1;
    }
}
