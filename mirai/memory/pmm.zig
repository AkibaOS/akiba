//! Physical Memory Manager

const asm_memory = @import("../asm/memory.zig");
const memory_const = @import("../common/constants/memory.zig");
const multiboot = @import("../boot/multiboot/multiboot.zig");
const paging_const = @import("../common/constants/paging.zig");
const pmm_const = @import("../common/constants/pmm.zig");
const serial = @import("../drivers/serial/serial.zig");

const PAGE_SIZE = memory_const.PAGE_SIZE;
const HIGHER_HALF = memory_const.HIGHER_HALF_START;

var bitmap: [*]u8 = undefined;
var bitmap_size: usize = 0;
var total_pages: u64 = 0;
var used_pages: u64 = 0;
var initialized: bool = false;

pub const MemoryInfo = struct {
    total: u64,
    used: u64,
};

pub fn init(kernel_end_phys: u64, memory_map: []multiboot.MemoryEntry) void {
    serial.print("\n=== PMM ===\n");

    var highest_addr: u64 = 0;
    for (memory_map) |entry| {
        if (entry.entry_type == pmm_const.MEMORY_AVAILABLE) {
            const end = entry.base + entry.length;
            if (end > highest_addr) {
                highest_addr = end;
            }
        }
    }

    total_pages = highest_addr / PAGE_SIZE;
    bitmap_size = (total_pages + 7) / 8;

    serial.printf("Memory: {} MB, {} pages\n", .{ highest_addr / (1024 * 1024), total_pages });

    const bitmap_phys = align_up(kernel_end_phys, PAGE_SIZE);
    bitmap = @ptrFromInt(bitmap_phys + HIGHER_HALF);

    for (0..bitmap_size) |i| {
        bitmap[i] = pmm_const.BITMAP_MARK_USED;
    }
    used_pages = total_pages;

    for (memory_map) |entry| {
        if (entry.entry_type == pmm_const.MEMORY_AVAILABLE) {
            free_region(entry.base, entry.length);
        }
    }

    const kernel_size = kernel_end_phys - pmm_const.KERNEL_BASE;
    const bitmap_pages = (bitmap_size + PAGE_SIZE - 1) / PAGE_SIZE;

    reserve_region(0, pmm_const.FIRST_MB);
    reserve_region(pmm_const.KERNEL_BASE, kernel_size);
    reserve_region(bitmap_phys, bitmap_pages * PAGE_SIZE);

    reserve_region(pmm_const.MMIO_PCI_BASE, pmm_const.MMIO_PCI_SIZE);
    reserve_region(pmm_const.MMIO_FRAMEBUFFER_BASE, pmm_const.MMIO_FRAMEBUFFER_SIZE);

    reserve_active_page_tables();

    serial.printf("Free: {} pages ({} MB)\n", .{ total_pages - used_pages, (total_pages - used_pages) * PAGE_SIZE / (1024 * 1024) });

    initialized = true;
}

pub fn alloc_page() ?u64 {
    if (!initialized) return null;

    for (0..total_pages) |i| {
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

    for (start_page..end_page) |page| {
        if (page < total_pages) {
            set_page_free(page);
        }
    }
}

fn reserve_region(base: u64, length: u64) void {
    const start_page = base / PAGE_SIZE;
    const end_page = (base + length + PAGE_SIZE - 1) / PAGE_SIZE;

    for (start_page..end_page) |page| {
        if (page < total_pages) {
            set_page_used(page);
        }
    }
}

fn is_page_used(page: u64) bool {
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
    return (bitmap[byte_index] & (@as(u8, 1) << bit_index)) != 0;
}

fn set_page_used(page: u64) void {
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
    if ((bitmap[byte_index] & (@as(u8, 1) << bit_index)) == 0) {
        bitmap[byte_index] |= (@as(u8, 1) << bit_index);
        used_pages += 1;
    }
}

fn set_page_free(page: u64) void {
    const byte_index = page / 8;
    const bit_index: u3 = @truncate(page % 8);
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

fn reserve_active_page_tables() void {
    const cr3 = asm_memory.read_page_table_base() & ~@as(u64, paging_const.OFFSET_MASK);

    reserve_region(cr3, PAGE_SIZE);

    const pml4: [*]volatile u64 = @ptrFromInt(cr3 + HIGHER_HALF);

    for (0..paging_const.PML4_ENTRIES) |pml4_i| {
        if ((pml4[pml4_i] & paging_const.PTE_PRESENT) == 0) continue;

        const pdpt_phys = pml4[pml4_i] & paging_const.PTE_MASK;
        reserve_region(pdpt_phys, PAGE_SIZE);

        const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF);

        for (0..paging_const.PML4_ENTRIES) |pdpt_i| {
            if ((pdpt[pdpt_i] & paging_const.PTE_PRESENT) == 0) continue;

            const pd_phys = pdpt[pdpt_i] & paging_const.PTE_MASK;
            reserve_region(pd_phys, PAGE_SIZE);

            const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF);

            for (0..paging_const.PML4_ENTRIES) |pd_i| {
                if ((pd[pd_i] & paging_const.PTE_PRESENT) == 0) continue;

                const pt_phys = pd[pd_i] & paging_const.PTE_MASK;
                reserve_region(pt_phys, PAGE_SIZE);
            }
        }
    }
}

pub fn get_info() MemoryInfo {
    return MemoryInfo{
        .total = total_pages,
        .used = used_pages,
    };
}
