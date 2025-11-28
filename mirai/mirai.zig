const serial = @import("drivers/serial.zig");
const multiboot = @import("boot/multiboot2.zig");
const pmm = @import("memory/pmm.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    serial.init();

    serial.print("\n");
    serial.print("═══════════════════════════════════\n");
    serial.print("   AKIBA OS - Hybrid Kernel\n");
    serial.print("═══════════════════════════════════\n");

    // Parse memory map
    const memory_map = multiboot.parse_memory_map(multiboot_info_addr);

    // Calculate kernel end (you'll need to add this to linker script)
    const kernel_end: u64 = 0x500000; // Estimate for now

    // Initialize PMM
    pmm.init(kernel_end, memory_map);

    // Test allocation
    serial.print("\n=== Testing PMM ===\n");

    if (pmm.alloc_page()) |page1| {
        serial.print("Allocated page 1: ");
        serial.print_hex(page1);
        serial.print("\n");

        if (pmm.alloc_page()) |page2| {
            serial.print("Allocated page 2: ");
            serial.print_hex(page2);
            serial.print("\n");

            serial.print("Freeing page 1...\n");
            pmm.free_page(page1);

            if (pmm.alloc_page()) |page3| {
                serial.print("Allocated page 3: ");
                serial.print_hex(page3);
                serial.print(" (should be same as page 1)\n");
            }
        }
    }

    serial.print("\n** System Ready **\n");

    while (true) {
        asm volatile ("hlt");
    }
}
