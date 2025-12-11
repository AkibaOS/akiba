//! Page Table Manager - Dynamic page table manipulation for hybrid kernel

const serial = @import("../drivers/serial.zig");
const pmm = @import("pmm.zig");

pub const PAGE_SIZE: u64 = 4096;
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

const PAGE_PRESENT: u64 = 1 << 0;
const PAGE_WRITABLE: u64 = 1 << 1;
const PAGE_USER: u64 = 1 << 2;

fn get_cr3() u64 {
    return asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (-> u64),
    );
}

fn invlpg(addr: u64) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true });
}

pub fn map_page(virt: u64, phys: u64, flags: u64) !void {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    // CR3 points to PML4 physical address
    const pml4_phys = get_cr3() & ~@as(u64, 0xFFF);
    // Access it via higher-half mapping
    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys + HIGHER_HALF_START);

    // Get or create PDPT
    var pdpt_phys: u64 = undefined;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pdpt_phys + HIGHER_HALF_START);
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pdpt_phys = pml4[pml4_index] & ~@as(u64, 0xFFF);
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    // Get or create PD
    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pd_phys = pdpt[pdpt_index] & ~@as(u64, 0xFFF);
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    // Get or create PT
    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pt_phys + HIGHER_HALF_START);
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pt_phys = pd[pd_index] & ~@as(u64, 0xFFF);
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    // Map the page
    pt[pt_index] = phys | PAGE_PRESENT | PAGE_WRITABLE | flags;

    invlpg(virt);
}

fn zero_page(virt: u64) void {
    const ptr: [*]volatile u8 = @ptrFromInt(virt);
    var i: usize = 0;
    while (i < PAGE_SIZE) : (i += 1) {
        ptr[i] = 0;
    }
}

// Create a new page table with kernel mappings copied
pub fn create_page_table() !u64 {
    // Allocate new PML4
    const new_pml4_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    const new_pml4: [*]volatile u64 = @ptrFromInt(new_pml4_phys + HIGHER_HALF_START);

    // Zero it out
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        new_pml4[i] = 0;
    }

    // Get current PML4 (kernel's page table)
    const kernel_pml4_phys = get_cr3() & ~@as(u64, 0xFFF);
    const kernel_pml4: [*]volatile u64 = @ptrFromInt(kernel_pml4_phys + HIGHER_HALF_START);

    // Copy identity mapping (PML4 entry 0: covers 0-512GB for kernel code/data)
    // This includes 2MB huge pages, but we'll break them down in map_page_in_table if needed
    new_pml4[0] = kernel_pml4[0];

    // Copy kernel mappings (upper half: entries 256-511)
    i = 256;
    while (i < 512) : (i += 1) {
        new_pml4[i] = kernel_pml4[i];
    }

    serial.print("Created new page table at ");
    serial.print_hex(new_pml4_phys);
    serial.print("\n");

    return new_pml4_phys;
}

// Map a page in a specific page table (not the current CR3)
// Returns: (was_already_mapped: bool, physical_address: u64)
pub fn map_page_in_table(page_table_phys: u64, virt: u64, phys: u64, flags: u64) !struct { bool, u64 } {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    const pml4: [*]volatile u64 = @ptrFromInt(page_table_phys + HIGHER_HALF_START);

    // Get or create PDPT
    var pdpt_phys: u64 = undefined;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pdpt_phys + HIGHER_HALF_START);
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pdpt_phys = pml4[pml4_index] & ~@as(u64, 0xFFF);
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    // Get or create PD
    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pd_phys = pdpt[pdpt_index] & ~@as(u64, 0xFFF);
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    // Check if PD entry is a 2MB huge page (bit 7 = PS bit set)
    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) != 0 and (pd[pd_index] & (1 << 7)) != 0) {
        // This is a 2MB huge page - we need to break it down into 4KB pages
        const huge_page_base = pd[pd_index] & ~@as(u64, 0x1FFFFF); // Clear lower 21 bits

        // Allocate a new PT to replace the huge page
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        const new_pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

        // Fill PT with 512 entries mapping the same physical range as the huge page
        var i: usize = 0;
        while (i < 512) : (i += 1) {
            const phys_addr = huge_page_base + (i * PAGE_SIZE);
            new_pt[i] = phys_addr | PAGE_PRESENT | PAGE_WRITABLE | (pd[pd_index] & PAGE_USER);
        }

        // Replace PD entry with PT (clear PS bit)
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | (pd[pd_index] & PAGE_USER);
    } else {
        // Get or create PT normally
        if ((pd[pd_index] & PAGE_PRESENT) == 0) {
            pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
            zero_page(pt_phys + HIGHER_HALF_START);
            pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
        } else {
            pt_phys = pd[pd_index] & ~@as(u64, 0xFFF);
        }
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    // Check if page is already mapped
    if ((pt[pt_index] & PAGE_PRESENT) != 0) {
        const existing_phys = pt[pt_index] & ~@as(u64, 0xFFF);
        return .{ true, existing_phys }; // Already mapped, return existing physical address
    }

    // Map the page
    pt[pt_index] = phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    return .{ false, phys }; // Newly mapped, return the physical address we just mapped
}

pub fn init() void {
    serial.print("\n=== Page Table Manager ===\n");
    serial.print("CR3: ");
    serial.print_hex(get_cr3());
    serial.print("\n");
}
