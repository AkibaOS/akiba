//! Kernel Stack Garbage Collection

const common = @import("common");

const constants = @import("../constants/constants.zig");
const kagami = @import("../../kagami/kagami.zig");
const pmm = @import("../../pmm/pmm.zig");
const state = @import("state.zig");

const limits = constants.stack.limits;
const sizes = common.constants.memory.sizes;

pub fn collect() u64 {
    const allocator_state = state.getState();
    const kernel_kagami = kagami.state.getKernelKagami();

    var released_pages: u64 = 0;

    while (allocator_state.FreeCount > limits.CACHE_TARGET) {
        const node = allocator_state.FreeList orelse break;
        allocator_state.FreeList = node.Next;
        allocator_state.FreeCount -= 1;

        const stack_base = @intFromPtr(node);

        var page_index: u64 = 0;
        while (page_index < limits.STACK_PAGES) : (page_index += 1) {
            const virtual_address = stack_base + page_index * sizes.PAGE_SIZE;
            if (kagami.remove.remove(kernel_kagami, virtual_address)) |physical_page| {
                pmm.free.single.freePage(physical_page);
                released_pages += 1;
            }
        }

        allocator_state.TotalCount -= 1;
    }

    return released_pages;
}
