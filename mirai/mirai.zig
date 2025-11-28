const serial = @import("drivers/serial.zig");
const multiboot = @import("boot/multiboot2.zig");
const pmm = @import("memory/pmm.zig");
const paging = @import("memory/paging.zig");
const heap = @import("memory/heap.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    serial.init();

    serial.print("\n");
    serial.print("═══════════════════════════════════\n");
    serial.print("   AKIBA OS - Memory Management\n");
    serial.print("═══════════════════════════════════\n");

    const memory_map = multiboot.parse_memory_map(multiboot_info_addr);
    const kernel_end: u64 = 0x500000;

    pmm.init(kernel_end, memory_map);
    paging.init();
    heap.init();

    // Test heap
    serial.print("\n=== Testing Heap ===\n");

    serial.print("\nSmall allocations:\n");
    const ptr1 = heap.alloc(32);
    if (ptr1) |p| {
        serial.print("  32B: ");
        serial.print_hex(@intFromPtr(p));
        serial.print("\n");
    }

    const ptr2 = heap.alloc(64);
    if (ptr2) |p| {
        serial.print("  64B: ");
        serial.print_hex(@intFromPtr(p));
        serial.print("\n");
    }

    serial.print("\nMultiple 64B allocations:\n");
    var i: u8 = 0;
    while (i < 5) : (i += 1) {
        if (heap.alloc(64)) |p| {
            serial.print("  [");
            serial.write('0' + i);
            serial.print("] ");
            serial.print_hex(@intFromPtr(p));
            serial.print("\n");
        }
    }

    serial.print("\nLarge allocation (8KB):\n");
    const large = heap.alloc(8192);
    if (large) |p| {
        serial.print("  8KB: ");
        serial.print_hex(@intFromPtr(p));
        serial.print("\n");
    }

    heap.print_stats();

    serial.print("\n** System Ready **\n");

    while (true) {
        asm volatile ("hlt");
    }
}
