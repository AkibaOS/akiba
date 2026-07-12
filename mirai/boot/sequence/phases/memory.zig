//! Memory Phase

const pmm = @import("../../../pmm/pmm.zig");
const kagami = @import("../../../kagami/kagami.zig");
const stack = @import("../../../memory/stack/stack.zig");
const serial = @import("../../../drivers/serial/serial.zig");
const tss = @import("../../tss/tss.zig");
const types = @import("../../types/sequence/sequence.zig");
const messages = @import("../../strings/sequence/sequence.zig").messages;

const BootInfo = types.BootInfo;

pub fn execute(boot_info: *const BootInfo) bool {
    serial.printf(messages.DETECTING, .{});

    const bitmap_location = find_bitmap_location(boot_info);
    if (bitmap_location == 0) {
        serial.printf(messages.NO_BITMAP, .{});
        return false;
    }

    pmm.initialize(boot_info.memory_map, boot_info.memory_map_count, bitmap_location);

    const stats = pmm.get_statistics();
    const total_mb = (stats.total_pages * 4096) / (1024 * 1024);
    const free_mb = (stats.free_pages * 4096) / (1024 * 1024);

    serial.printf(messages.FOUND_PAGES, .{ stats.total_pages, total_mb });
    serial.printf(messages.AVAILABLE, .{ stats.free_pages, free_mb });

    serial.printf(messages.KAGAMI_SETUP, .{});
    kagami.initialize(boot_info.pml4_physical);
    serial.printf(messages.PML4, .{boot_info.pml4_physical});

    serial.printf(messages.PROVISIONING_STACK, .{});
    const boot_stack = stack.allocate() catch {
        serial.printf(messages.NO_STACK, .{});
        return false;
    };
    tss.set_current_rsp0(0, boot_stack.top);
    serial.printf(messages.STACK_INFO, .{ boot_stack.base, boot_stack.top });

    return true;
}

fn find_bitmap_location(boot_info: *const BootInfo) u64 {
    const bitmap_size = pmm.constants.bitmap_size_bytes;
    const required_pages = (bitmap_size + 4095) / 4096;

    var index: u64 = 0;
    while (index < boot_info.memory_map_count) : (index += 1) {
        const region = boot_info.memory_map[index];

        if (!region.is_usable()) continue;

        if (region.base_address < 0x100000) continue;

        if (region.base_address >= boot_info.kernel_physical_base and
            region.base_address < boot_info.kernel_physical_end)
        {
            continue;
        }

        const region_pages = region.page_count();
        if (region_pages >= required_pages) {
            return region.base_address;
        }
    }

    return 0;
}
