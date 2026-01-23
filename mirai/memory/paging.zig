//! Page Table Manager - Hybrid kernel with independent user page tables

const pmm = @import("pmm.zig");
const serial = @import("../drivers/serial.zig");

pub const PAGE_SIZE: u64 = 4096;
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

const PAGE_PRESENT: u64 = 1 << 0;
const PAGE_WRITABLE: u64 = 1 << 1;
const PAGE_USER: u64 = 1 << 2;

// Kernel occupies 0x100000 - 0x500000 (4MB)
const KERNEL_START: u64 = 0x100000;
const KERNEL_END: u64 = 0x500000;

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

fn zero_page(virt: u64) void {
    const ptr: [*]volatile u8 = @ptrFromInt(virt);
    var i: usize = 0;
    while (i < PAGE_SIZE) : (i += 1) {
        ptr[i] = 0;
    }
}

// Map a page in the current page table (used by kernel for its own mappings)
pub fn map_page(virt: u64, phys: u64, flags: u64) !void {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    const pml4_phys = get_cr3() & ~@as(u64, 0xFFF);
    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys + HIGHER_HALF_START);

    var pdpt_phys: u64 = undefined;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pdpt_phys + HIGHER_HALF_START);
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pdpt_phys = pml4[pml4_index] & ~@as(u64, 0xFFF);
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pd_phys = pdpt[pdpt_index] & ~@as(u64, 0xFFF);
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pt_phys + HIGHER_HALF_START);
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
    } else {
        pt_phys = pd[pd_index] & ~@as(u64, 0xFFF);
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    pt[pt_index] = phys | PAGE_PRESENT | flags;

    invlpg(virt);
}

// Create completely independent page table structure for user
pub fn create_page_table() !u64 {
    const new_pml4_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    const new_pml4: [*]volatile u64 = @ptrFromInt(new_pml4_phys + HIGHER_HALF_START);

    var i: usize = 0;
    while (i < 512) : (i += 1) {
        new_pml4[i] = 0;
    }

    const kernel_pml4_phys = get_cr3() & ~@as(u64, 0xFFF);
    const kernel_pml4: [*]volatile u64 = @ptrFromInt(kernel_pml4_phys + HIGHER_HALF_START);

    // Copy higher-half mappings (PML4[256-511]) for kernel heap/data access
    i = 256;
    while (i < 512) : (i += 1) {
        new_pml4[i] = kernel_pml4[i];
    }

    // Map kernel (0x100000-0x1000000 = 16MB) as supervisor-only
    var addr: u64 = 0x100000;
    while (addr < 0x1000000) : (addr += PAGE_SIZE) {
        _ = try map_page_in_table(new_pml4_phys, addr, addr, PAGE_PRESENT | PAGE_WRITABLE);
    }

    // Map MMIO region (0x80000000-0x82000000 = 32MB) for framebuffer and AHCI
    // Supervisor-only
    addr = 0x80000000;
    while (addr < 0x82000000) : (addr += PAGE_SIZE) {
        _ = try map_page_in_table(new_pml4_phys, addr, addr, PAGE_PRESENT | PAGE_WRITABLE);
    }

    return new_pml4_phys;
}

// Map a page in a specific page table
pub fn map_page_in_table(page_table_phys: u64, virt: u64, phys: u64, flags: u64) !struct { bool, u64 } {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    const pml4: [*]volatile u64 = @ptrFromInt(page_table_phys + HIGHER_HALF_START);

    var pdpt_phys: u64 = undefined;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pdpt_phys + HIGHER_HALF_START);
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
    } else {
        pdpt_phys = pml4[pml4_index] & ~@as(u64, 0xFFF);
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
    } else {
        pd_phys = pdpt[pdpt_index] & ~@as(u64, 0xFFF);
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pt_phys + HIGHER_HALF_START);
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
    } else {
        pt_phys = pd[pd_index] & ~@as(u64, 0xFFF);
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    const was_mapped = (pt[pt_index] & PAGE_PRESENT) != 0;
    if (!was_mapped) {
        pt[pt_index] = phys | flags | PAGE_PRESENT;
        return .{ false, phys };
    } else {
        const existing_phys = pt[pt_index] & ~@as(u64, 0xFFF);
        return .{ true, existing_phys };
    }
}

pub fn get_physical_address(page_table: u64, vaddr: u64) !u64 {
    const pml4_index = (vaddr >> 39) & 0x1FF;
    const pdp_index = (vaddr >> 30) & 0x1FF;
    const pd_index = (vaddr >> 21) & 0x1FF;
    const pt_index = (vaddr >> 12) & 0x1FF;
    const offset = vaddr & 0xFFF;

    const pml4 = @as([*]u64, @ptrFromInt(page_table + HIGHER_HALF_START));
    if ((pml4[pml4_index] & 1) == 0) return error.NotMapped;

    const pdp = @as([*]u64, @ptrFromInt((pml4[pml4_index] & ~@as(u64, 0xFFF)) + HIGHER_HALF_START));
    if ((pdp[pdp_index] & 1) == 0) return error.NotMapped;

    const pd = @as([*]u64, @ptrFromInt((pdp[pdp_index] & ~@as(u64, 0xFFF)) + HIGHER_HALF_START));
    if ((pd[pd_index] & 1) == 0) return error.NotMapped;

    const pt = @as([*]u64, @ptrFromInt((pd[pd_index] & ~@as(u64, 0xFFF)) + HIGHER_HALF_START));
    if ((pt[pt_index] & 1) == 0) return error.NotMapped;

    return (pt[pt_index] & ~@as(u64, 0xFFF)) + offset;
}

pub fn virt_to_phys(cr3: u64, virt: u64) ?u64 {
    // Walk the 4-level page table
    const pml4_addr = cr3 + HIGHER_HALF_START;
    const pml4 = @as([*]u64, @ptrFromInt(pml4_addr));

    const pml4_index = (virt >> 39) & 0x1FF;
    const pml4_entry = pml4[pml4_index];

    if ((pml4_entry & 1) == 0) return null; // Not present

    const pdp_addr = (pml4_entry & 0x000FFFFFFFFFF000) + HIGHER_HALF_START;
    const pdp = @as([*]u64, @ptrFromInt(pdp_addr));

    const pdp_index = (virt >> 30) & 0x1FF;
    const pdp_entry = pdp[pdp_index];

    if ((pdp_entry & 1) == 0) return null; // Not present

    const pd_addr = (pdp_entry & 0x000FFFFFFFFFF000) + HIGHER_HALF_START;
    const pd = @as([*]u64, @ptrFromInt(pd_addr));

    const pd_index = (virt >> 21) & 0x1FF;
    const pd_entry = pd[pd_index];

    if ((pd_entry & 1) == 0) return null; // Not present

    const pt_addr = (pd_entry & 0x000FFFFFFFFFF000) + HIGHER_HALF_START;
    const pt = @as([*]u64, @ptrFromInt(pt_addr));

    const pt_index = (virt >> 12) & 0x1FF;
    const pt_entry = pt[pt_index];

    if ((pt_entry & 1) == 0) return null; // Not present

    const phys_base = pt_entry & 0x000FFFFFFFFFF000;
    const offset = virt & 0xFFF;

    return phys_base + offset;
}

pub fn init() void {}
