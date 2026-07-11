//! Memory Phase

const pmm = @import("../../../pmm/pmm.zig");
const kagami = @import("../../../kagami/kagami.zig");
const stack = @import("../../../memory/stack/stack.zig");
const serial = @import("../../../drivers/serial/serial.zig");
const tss = @import("../../tss/tss.zig");
const types = @import("../types/types.zig");
const messages = @import("../strings/strings.zig").messages;

const BootInfo = types.BootInfo;

pub fn execute(boot_info: *const BootInfo) bool {
    serial.printf(messages.detecting, .{});

    const bitmap_location = find_bitmap_location(boot_info);
    if (bitmap_location == 0) {
        serial.printf(messages.no_bitmap, .{});
        return false;
    }

    pmm.initialize(boot_info.memory_map, boot_info.memory_map_count, bitmap_location);

    const stats = pmm.get_statistics();
    const total_mb = (stats.total_pages * 4096) / (1024 * 1024);
    const free_mb = (stats.free_pages * 4096) / (1024 * 1024);

    serial.printf(messages.found_pages, .{ stats.total_pages, total_mb });
    serial.printf(messages.available, .{ stats.free_pages, free_mb });

    serial.printf(messages.kagami_setup, .{});
    kagami.initialize(boot_info.pml4_physical);
    serial.printf(messages.pml4, .{boot_info.pml4_physical});

    serial.printf(messages.provisioning_stack, .{});
    const boot_stack = stack.allocate() catch {
        serial.printf(messages.no_stack, .{});
        return false;
    };
    tss.set_current_rsp0(0, boot_stack.top);
    serial.printf(messages.stack_info, .{ boot_stack.base, boot_stack.top });

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
