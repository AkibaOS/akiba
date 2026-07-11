//! Kernel Stack Garbage Collection

const common = @import("root").common;
const kagami = @import("../../../kagami/kagami.zig");
const pmm = @import("../../../pmm/pmm.zig");
const constants = @import("../constants/constants.zig");
const state = @import("../state.zig");

const sizes = common.constants.memory.sizes;

pub fn collect() u64 {
    const allocator_state = state.get_state();
    const kernel_kagami = kagami.kernel();

    var released_pages: u64 = 0;

    while (allocator_state.free_count > constants.cache_target) {
        const node = allocator_state.free_list orelse break;
        allocator_state.free_list = node.next;
        allocator_state.free_count -= 1;

        const stack_base = @intFromPtr(node);

        var page_index: u64 = 0;
        while (page_index < constants.stack_pages) : (page_index += 1) {
            const virtual_address = stack_base + page_index * sizes.page_size;
            if (kagami.remove(kernel_kagami, virtual_address)) |physical_page| {
                pmm.free_page(physical_page);
                released_pages += 1;
            }
        }

        allocator_state.total_count -= 1;
    }

    return released_pages;
}
