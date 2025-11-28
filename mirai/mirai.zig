const serial = @import("drivers/serial.zig");
const multiboot = @import("boot/multiboot2.zig");
const pmm = @import("memory/pmm.zig");
const paging = @import("memory/paging.zig");
const heap = @import("memory/heap.zig");
const idt = @import("interrupts/idt.zig");
const keyboard = @import("drivers/keyboard.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    serial.init();

    serial.print("\n");
    serial.print("═══════════════════════════════════\n");
    serial.print("      AKIBA OS - Full System\n");
    serial.print("═══════════════════════════════════\n");

    const memory_map = multiboot.parse_memory_map(multiboot_info_addr);
    const kernel_end: u64 = 0x500000;

    pmm.init(kernel_end, memory_map);
    paging.init();
    heap.init();

    idt.init();
    keyboard.init();

    serial.print("\n** System Ready - Type something! **\n");
    serial.print("Press any key to trigger divide-by-zero exception test\n\n");

    // Wait a bit
    var ticks: u64 = 0;
    while (ticks < 100000000) : (ticks += 1) {
        asm volatile ("pause");
    }

    // Test divide by zero (use inline assembly to prevent compile-time detection)
    serial.print("\nTesting divide-by-zero exception...\n");
    test_divide_by_zero();

    while (true) {
        asm volatile ("hlt");
    }
}

fn test_divide_by_zero() void {
    // Inline assembly to prevent Zig from detecting this at compile time
    asm volatile (
        \\mov $42, %%eax
        \\xor %%ebx, %%ebx
        \\div %%ebx
        ::: .{ .eax = true, .ebx = true, .edx = true });
}

fn test_page_fault() void {
    // Try to write to unmapped memory
    const bad_ptr: *volatile u64 = @ptrFromInt(0xDEADBEEF);
    bad_ptr.* = 0x12345678;
}
