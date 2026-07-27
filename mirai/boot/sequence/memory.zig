//! Memory Phase

const common = @import("common");

const kagami = @import("../../kagami/kagami.zig");
const pmm = @import("../../pmm/pmm.zig");
const serial = @import("../../drivers/serial/serial.zig");
const stack = @import("../../memory/stack/stack.zig");
const strings = @import("../strings/strings.zig");
const tss = @import("../tss/tss.zig");
const types = @import("../types/types.zig");

const layout = common.constants.memory.layout;
const messages = strings.sequence.messages;
const sizes = common.constants.memory.sizes;

const BootInfo = types.sequence.info.BootInfo;

pub fn execute(boot_info: *const BootInfo) bool {
    serial.write.printf(messages.DETECTING, .{});

    const bitmap_location = findBitmapLocation(boot_info);
    if (bitmap_location == 0) {
        serial.write.printf(messages.NO_BITMAP, .{});
        return false;
    }

    pmm.init.setup.initializeFromMemoryMap(boot_info.MemoryMap, boot_info.MemoryMapCount, bitmap_location);

    const statistics = pmm.state.getStatistics();
    const total_megabytes = (statistics.TotalPages * sizes.PAGE_SIZE) / sizes.MEGABYTE;
    const free_megabytes = (statistics.FreePages * sizes.PAGE_SIZE) / sizes.MEGABYTE;

    serial.write.printf(messages.FOUND_PAGES, .{ statistics.TotalPages, total_megabytes });
    serial.write.printf(messages.AVAILABLE, .{ statistics.FreePages, free_megabytes });

    serial.write.printf(messages.KAGAMI_SETUP, .{});
    kagami.state.initialize(boot_info.PML4Physical);
    serial.write.printf(messages.PML4, .{boot_info.PML4Physical});

    serial.write.printf(messages.PROVISIONING_STACK, .{});
    const boot_stack = stack.allocate.allocate() catch {
        serial.write.printf(messages.NO_STACK, .{});
        return false;
    };
    tss.state.setCurrentRSP0(0, boot_stack.Top);
    serial.write.printf(messages.STACK_INFO, .{ boot_stack.Base, boot_stack.Top });

    return true;
}

fn findBitmapLocation(boot_info: *const BootInfo) u64 {
    const bitmap_size = pmm.constants.limits.BITMAP_SIZE_BYTES;
    const required_pages = (bitmap_size + sizes.PAGE_MASK) / sizes.PAGE_SIZE;

    var index: u64 = 0;
    while (index < boot_info.MemoryMapCount) : (index += 1) {
        const region = boot_info.MemoryMap[index];

        if (!region.isUsable()) continue;

        if (region.BaseAddress < layout.KERNEL_PHYSICAL_BASE) continue;

        if (region.BaseAddress >= boot_info.KernelPhysicalBase and
            region.BaseAddress < boot_info.KernelPhysicalEnd)
        {
            continue;
        }

        const region_pages = region.pageCount();
        if (region_pages >= required_pages) {
            return region.BaseAddress;
        }
    }

    return 0;
}
