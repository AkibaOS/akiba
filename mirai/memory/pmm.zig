//! Physical Memory Manager - Tracks free/used 4KB pages using a bitmap

const mem = @import("../asm/memory.zig");
const multiboot = @import("../boot/multiboot2.zig");
const serial = @import("../drivers/serial.zig");
const system = @import("../system/system.zig");

const PAGE_SIZE = system.constants.PAGE_SIZE;
const HIGHER_HALF_START = system.constants.HIGHER_HALF_START;

var bitmap: [*]u8 = undefined;
var bitmap_size: usize = 0;
var total_pages: u64 = 0;
var used_pages: u64 = 0;
var initialized: bool = false;

pub fn init(kernel_end_phys: u64, memory_map: []multiboot.MemoryEntry) void {
    serial.print("\n=== Physical Memory Manager ===\n");

    // Find highest memory address
    var highest_addr: u64 = 0;
    for (memory_map) |entry| {
        if (entry.entry_type == 1) { // Available
            const end = entry.base + entry.length;
            if (end > highest_addr) {
                highest_addr = end;
            }
        }
    }

    total_pages = highest_addr / PAGE_SIZE;
    bitmap_size = (total_pages + 7) / 8; // Convert bits to bytes

    serial.print("Total memory: ");
    serial.print_hex(highest_addr / (1024 * 1024));
    serial.print(" MB\n");
    serial.print("Total pages: ");
    serial.print_hex(total_pages);
    serial.print("\n");
    serial.print("Bitmap size: ");
    serial.print_hex(bitmap_size);
    serial.print(" bytes\n");

    // Place bitmap in higher-half memory (after kernel)
    const bitmap_phys = align_up(kernel_end_phys, PAGE_SIZE);
    bitmap = @ptrFromInt(bitmap_phys + HIGHER_HALF_START);

    serial.print("Bitmap physical: ");
    serial.print_hex(bitmap_phys);
    serial.print("\n");
    serial.print("Bitmap virtual: ");
    serial.print_hex(@intFromPtr(bitmap));
    serial.print("\n");

    // Mark all pages as used initially
    var i: usize = 0;
    while (i < bitmap_size) : (i += 1) {
        bitmap[i] = 0xFF;
    }
    used_pages = total_pages;

    // Mark available regions as free
    for (memory_map) |entry| {
        if (entry.entry_type == 1) { // Available
            free_region(entry.base, entry.length);
        }
    }

    // Reserve kernel and bitmap
    const kernel_size = kernel_end_phys - 0x100000;
    const bitmap_pages = (bitmap_size + PAGE_SIZE - 1) / PAGE_SIZE;

    reserve_region(0, 0x100000); // Reserve first 1MB
    reserve_region(0x100000, kernel_size);
    reserve_region(bitmap_phys, bitmap_pages * PAGE_SIZE);

    // Reserve MMIO regions (PCI, AHCI, framebuffer, etc.)
    // PCI configuration space and above
    reserve_region(0xE0000000, 0x10000000); // 256MB PCI MMIO region
    reserve_region(0x80000000, 0x10000000); // Framebuffer and device MMIO (includes AHCI ABAR at 0x81084000)

    // Reserve currently active page tables to prevent reallocation
    reserve_active_page_tables();

    serial.print("Free pages: ");
    serial.print_hex(total_pages - used_pages);
    serial.print(" (");
    serial.print_hex((total_pages - used_pages) * PAGE_SIZE / (1024 * 1024));
    serial.print(" MB)\n");
    serial.print("Used pages: ");
    serial.print_hex(used_pages);
    serial.print("\n");

    initialized = true;
}

pub fn alloc_page() ?u64 {
    if (!initialized) return null;

    var i: u64 = 0;
    while (i < total_pages) : (i += 1) {
        if (!is_page_used(i)) {
            set_page_used(i);
            return i * PAGE_SIZE;
        }
    }
    return null;
}

pub fn free_page(phys_addr: u64) void {
    if (!initialized) return;

    const page = phys_addr / PAGE_SIZE;
    if (page < total_pages) {
        set_page_free(page);
    }
}

fn free_region(base: u64, length: u64) void {
    const start_page = align_up(base, PAGE_SIZE) / PAGE_SIZE;
    const end_page = align_down(base + length, PAGE_SIZE) / PAGE_SIZE;

    var page = start_page;
    while (page < end_page) : (page += 1) {
        if (page < total_pages) {
            set_page_free(page);
        }
    }
}

fn reserve_region(base: u64, length: u64) void {
    const start_page = base / PAGE_SIZE;
    const end_page = (base + length + PAGE_SIZE - 1) / PAGE_SIZE;

    var page = start_page;
    while (page < end_page) : (page += 1) {
        if (page < total_pages) {
            set_page_used(page);
        }
    }
}

fn is_page_used(page: u64) bool {
    const byte_index = page / 8;
    const bit_index = @as(u3, @truncate(page % 8));
    return (bitmap[byte_index] & (@as(u8, 1) << bit_index)) != 0;
}

fn set_page_used(page: u64) void {
    const byte_index = page / 8;
    const bit_index = @as(u3, @truncate(page % 8));
    if ((bitmap[byte_index] & (@as(u8, 1) << bit_index)) == 0) {
        bitmap[byte_index] |= (@as(u8, 1) << bit_index);
        used_pages += 1;
    }
}

fn set_page_free(page: u64) void {
    const byte_index = page / 8;
    const bit_index = @as(u3, @truncate(page % 8));
    if ((bitmap[byte_index] & (@as(u8, 1) << bit_index)) != 0) {
        bitmap[byte_index] &= ~(@as(u8, 1) << bit_index);
        used_pages -= 1;
    }
}

fn align_up(addr: u64, alignment: u64) u64 {
    return (addr + alignment - 1) & ~(alignment - 1);
}

fn align_down(addr: u64, alignment: u64) u64 {
    return addr & ~(alignment - 1);
}

fn get_cr3() u64 {
    return mem.read_page_table_base();
}

/// Reserve all page table pages currently in use by walking CR3 hierarchy
fn reserve_active_page_tables() void {
    const PAGE_PRESENT: u64 = 1;

    const cr3 = get_cr3() & ~@as(u64, 0xFFF);

    // Reserve PML4 page
    reserve_region(cr3, PAGE_SIZE);

    const pml4: [*]volatile u64 = @ptrFromInt(cr3 + HIGHER_HALF_START);

    // Walk PML4
    var pml4_i: usize = 0;
    while (pml4_i < 512) : (pml4_i += 1) {
        if ((pml4[pml4_i] & PAGE_PRESENT) == 0) continue;

        const pdpt_phys = pml4[pml4_i] & ~@as(u64, 0xFFF);
        reserve_region(pdpt_phys, PAGE_SIZE);

        const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

        // Walk PDPT
        var pdpt_i: usize = 0;
        while (pdpt_i < 512) : (pdpt_i += 1) {
            if ((pdpt[pdpt_i] & PAGE_PRESENT) == 0) continue;

            const pd_phys = pdpt[pdpt_i] & ~@as(u64, 0xFFF);
            reserve_region(pd_phys, PAGE_SIZE);

            const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

            // Walk PD
            var pd_i: usize = 0;
            while (pd_i < 512) : (pd_i += 1) {
                if ((pd[pd_i] & PAGE_PRESENT) == 0) continue;

                const pt_phys = pd[pd_i] & ~@as(u64, 0xFFF);
                reserve_region(pt_phys, PAGE_SIZE);
            }
        }
    }
}
