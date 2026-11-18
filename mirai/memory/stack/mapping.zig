//! Owned Kernel Stack Mapping Validation And Unwind

const common = @import("common");
const kagami = @import("mirai").kagami;
const labels = @import("mirai").memory.strings.stack.storage;
const limits = @import("mirai").memory.constants.stack.limits;
const pmm = @import("mirai").pmm;
const state = @import("mirai").memory.stack.state;
const types = @import("mirai").memory.types.stack;

const sizes = common.constants.memory.sizes;
const Record = types.record.Record;

pub fn validate(record: *const Record) bool {
    if (!state.owns(record)) return false;
    const stack = record.Stack;
    if (record.PageCount != limits.STACK_PAGES or record.Extent.Size != limits.SLOT_SIZE or
        stack.Base != record.Extent.Base + limits.GUARD_PAGES * sizes.PAGE_SIZE or
        stack.Top != stack.Base + limits.STACK_SIZE) return false;
    const kernel = kagami.state.getKernelKagami();
    if (kagami.extract.isMapped(kernel, stack.Base - sizes.PAGE_SIZE) or kagami.extract.isMapped(kernel, stack.Top)) return false;
    for (record.Pages, 0..) |physical, index| {
        if (!pmm.state.isAllocated(physical)) return false;
        const mapped = kagami.extract.lookup(kernel, stack.Base + index * sizes.PAGE_SIZE) orelse return false;
        if (mapped.PageSize != sizes.PAGE_SIZE or mapped.PhysicalAddress != physical or !mapped.Writable or
            mapped.Executable or mapped.UserAccessible or !mapped.Entry.isWired()) return false;
    }
    return true;
}

pub fn unwind(record: *Record) void {
    while (record.PageCount != 0) {
        record.PageCount -= 1;
        const physical = record.Pages[record.PageCount];
        const address = record.Stack.Base + record.PageCount * sizes.PAGE_SIZE;
        const removed = kagami.remove.remove(kagami.state.getKernelKagami(), address) orelse @panic(labels.INVALID_STATE);
        if (removed != physical) @panic(labels.INVALID_STATE);
        pmm.free.single.freePage(physical);
        record.Pages[record.PageCount] = 0;
    }
}
