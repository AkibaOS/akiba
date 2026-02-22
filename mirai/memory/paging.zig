//! Page Table Manager

const asm_memory = @import("../asm/memory.zig");
const memory_const = @import("../common/constants/memory.zig");
const paging_const = @import("../common/constants/paging.zig");
const pmm = @import("pmm.zig");
const pmm_const = @import("../common/constants/pmm.zig");

pub const PAGE_SIZE = memory_const.PAGE_SIZE;
pub const HIGHER_HALF_START = memory_const.HIGHER_HALF_START;

pub const PAGE_PRESENT = paging_const.PTE_PRESENT;
pub const PAGE_WRITABLE = paging_const.PTE_WRITABLE;
pub const PAGE_USER = paging_const.PTE_USER;

fn zero_page(virt: u64) void {
    const ptr: [*]volatile u8 = @ptrFromInt(virt);
    for (0..PAGE_SIZE) |i| {
        ptr[i] = 0;
    }
}

pub fn map_page(virt: u64, phys: u64, flags: u64) !void {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    const pml4_phys = asm_memory.read_page_table_base() & ~@as(u64, paging_const.OFFSET_MASK);
    const pml4: [*]volatile u64 = @ptrFromInt(pml4_phys + HIGHER_HALF_START);

    var pdpt_phys: u64 = undefined;
    var pdpt_was_new = false;
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) {
        pdpt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        pml4[pml4_index] = pdpt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
        pdpt_was_new = true;
    } else {
        pdpt_phys = pml4[pml4_index] & paging_const.PTE_MASK;
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    if (pdpt_was_new) {
        pdpt[pdpt_index] = 0;
    }

    var pd_phys: u64 = undefined;
    var pd_was_new = false;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
        pd_was_new = true;
    } else {
        pd_phys = pdpt[pdpt_index] & paging_const.PTE_MASK;
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    if (pd_was_new) {
        pd[pd_index] = 0;
    }

    var pt_phys: u64 = undefined;
    var pt_was_new = false;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | flags;
        pt_was_new = true;
    } else {
        pt_phys = pd[pd_index] & paging_const.PTE_MASK;
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    if (pt_was_new) {
        pt[pt_index] = 0;
    }

    pt[pt_index] = phys | PAGE_PRESENT | flags;

    asm_memory.invalidate_page(virt);
}

pub fn create_page_table() !u64 {
    const new_pml4_phys = pmm.alloc_page() orelse return error.OutOfMemory;
    const new_pml4: [*]volatile u64 = @ptrFromInt(new_pml4_phys + HIGHER_HALF_START);

    for (0..paging_const.PML4_ENTRIES) |i| {
        new_pml4[i] = 0;
    }

    const kernel_pml4_phys = asm_memory.read_page_table_base() & ~@as(u64, paging_const.OFFSET_MASK);
    const kernel_pml4: [*]volatile u64 = @ptrFromInt(kernel_pml4_phys + HIGHER_HALF_START);

    for (paging_const.KERNEL_PML4_START..paging_const.PML4_ENTRIES) |i| {
        new_pml4[i] = kernel_pml4[i];
    }

    var addr: u64 = pmm_const.KERNEL_BASE;
    while (addr < pmm_const.KERNEL_MAP_END) : (addr += PAGE_SIZE) {
        _ = try map_page_in_table(new_pml4_phys, addr, addr, PAGE_PRESENT | PAGE_WRITABLE);
    }

    addr = pmm_const.MMIO_FRAMEBUFFER_BASE;
    while (addr < pmm_const.MMIO_FRAMEBUFFER_BASE + 0x2000000) : (addr += PAGE_SIZE) {
        _ = try map_page_in_table(new_pml4_phys, addr, addr, PAGE_PRESENT | PAGE_WRITABLE);
    }

    return new_pml4_phys;
}

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
        pdpt_phys = pml4[pml4_index] & paging_const.PTE_MASK;
    }

    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

    var pd_phys: u64 = undefined;
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) {
        pd_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pd_phys + HIGHER_HALF_START);
        pdpt[pdpt_index] = pd_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
    } else {
        pd_phys = pdpt[pdpt_index] & paging_const.PTE_MASK;
    }

    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

    var pt_phys: u64 = undefined;
    if ((pd[pd_index] & PAGE_PRESENT) == 0) {
        pt_phys = pmm.alloc_page() orelse return error.OutOfMemory;
        zero_page(pt_phys + HIGHER_HALF_START);
        pd[pd_index] = pt_phys | PAGE_PRESENT | PAGE_WRITABLE | PAGE_USER;
    } else {
        pt_phys = pd[pd_index] & paging_const.PTE_MASK;
    }

    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    const was_mapped = (pt[pt_index] & PAGE_PRESENT) != 0;
    if (!was_mapped) {
        pt[pt_index] = phys | flags | PAGE_PRESENT;
        return .{ false, phys };
    } else {
        const existing_phys = pt[pt_index] & paging_const.PTE_MASK;
        pt[pt_index] = existing_phys | flags | PAGE_PRESENT;
        return .{ true, existing_phys };
    }
}

pub fn get_physical_address(page_table: u64, vaddr: u64) !u64 {
    const pml4_index = (vaddr >> 39) & 0x1FF;
    const pdp_index = (vaddr >> 30) & 0x1FF;
    const pd_index = (vaddr >> 21) & 0x1FF;
    const pt_index = (vaddr >> 12) & 0x1FF;
    const offset = vaddr & paging_const.OFFSET_MASK;

    const pml4 = @as([*]u64, @ptrFromInt(page_table + HIGHER_HALF_START));
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) return error.NotMapped;

    const pdp = @as([*]u64, @ptrFromInt((pml4[pml4_index] & paging_const.PTE_MASK) + HIGHER_HALF_START));
    if ((pdp[pdp_index] & PAGE_PRESENT) == 0) return error.NotMapped;

    const pd = @as([*]u64, @ptrFromInt((pdp[pdp_index] & paging_const.PTE_MASK) + HIGHER_HALF_START));
    if ((pd[pd_index] & PAGE_PRESENT) == 0) return error.NotMapped;

    const pt = @as([*]u64, @ptrFromInt((pd[pd_index] & paging_const.PTE_MASK) + HIGHER_HALF_START));
    if ((pt[pt_index] & PAGE_PRESENT) == 0) return error.NotMapped;

    return (pt[pt_index] & paging_const.PTE_MASK) + offset;
}

pub fn get_page_entry(page_table_phys: u64, virt: u64) ?u64 {
    const pml4_index = (virt >> 39) & 0x1FF;
    const pdpt_index = (virt >> 30) & 0x1FF;
    const pd_index = (virt >> 21) & 0x1FF;
    const pt_index = (virt >> 12) & 0x1FF;

    const pml4: [*]volatile u64 = @ptrFromInt(page_table_phys + HIGHER_HALF_START);
    if ((pml4[pml4_index] & PAGE_PRESENT) == 0) return null;

    const pdpt_phys = pml4[pml4_index] & paging_const.PTE_MASK;
    const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);
    if ((pdpt[pdpt_index] & PAGE_PRESENT) == 0) return null;

    const pd_phys = pdpt[pdpt_index] & paging_const.PTE_MASK;
    const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);
    if ((pd[pd_index] & PAGE_PRESENT) == 0) return null;

    const pt_phys = pd[pd_index] & paging_const.PTE_MASK;
    const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

    return pt[pt_index];
}

pub fn virt_to_phys(cr3: u64, virt: u64) ?u64 {
    const pml4_addr = cr3 + HIGHER_HALF_START;
    const pml4 = @as([*]u64, @ptrFromInt(pml4_addr));

    const pml4_index = (virt >> 39) & 0x1FF;
    const pml4_entry = pml4[pml4_index];

    if ((pml4_entry & PAGE_PRESENT) == 0) return null;

    const pdp_addr = (pml4_entry & paging_const.PTE_MASK) + HIGHER_HALF_START;
    const pdp = @as([*]u64, @ptrFromInt(pdp_addr));

    const pdp_index = (virt >> 30) & 0x1FF;
    const pdp_entry = pdp[pdp_index];

    if ((pdp_entry & PAGE_PRESENT) == 0) return null;

    const pd_addr = (pdp_entry & paging_const.PTE_MASK) + HIGHER_HALF_START;
    const pd = @as([*]u64, @ptrFromInt(pd_addr));

    const pd_index = (virt >> 21) & 0x1FF;
    const pd_entry = pd[pd_index];

    if ((pd_entry & PAGE_PRESENT) == 0) return null;

    const pt_addr = (pd_entry & paging_const.PTE_MASK) + HIGHER_HALF_START;
    const pt = @as([*]u64, @ptrFromInt(pt_addr));

    const pt_index = (virt >> 12) & 0x1FF;
    const pt_entry = pt[pt_index];

    if ((pt_entry & PAGE_PRESENT) == 0) return null;

    const phys_base = pt_entry & paging_const.PTE_MASK;
    const offset = virt & paging_const.OFFSET_MASK;

    return phys_base + offset;
}

/// Check if a page should be freed based on virtual and physical address
/// Returns true if the page should be freed, false if it's shared
fn should_free_page(virt: u64, phys: u64) bool {
    // Identity-mapped kernel region (kernel code, data, PMM bitmap)
    // These physical pages are shared - don't free
    if (virt < pmm_const.KERNEL_MAP_END) {
        return false;
    }
    // Framebuffer region - hardware memory, not PMM managed
    if (phys >= pmm_const.MMIO_FRAMEBUFFER_BASE and
        phys < pmm_const.MMIO_FRAMEBUFFER_BASE + pmm_const.MMIO_FRAMEBUFFER_SIZE)
    {
        return false;
    }
    // Everything else (user stack, program segments, etc.) should be freed
    return true;
}

/// Destroy a page table and free all associated memory
/// Frees: user pages, page table structures
/// Does NOT free: shared kernel pages, framebuffer
pub fn destroy_page_table(page_table_phys: u64) void {
    const pml4: [*]volatile u64 = @ptrFromInt(page_table_phys + HIGHER_HALF_START);

    // Only walk user-space PML4 entries (0-255)
    // Entries 256-511 are shared kernel mappings, don't touch
    for (0..paging_const.KERNEL_PML4_START) |pml4_idx| {
        const pml4_entry = pml4[pml4_idx];
        if ((pml4_entry & PAGE_PRESENT) == 0) continue;

        const pdpt_phys = pml4_entry & paging_const.PTE_MASK;
        const pdpt: [*]volatile u64 = @ptrFromInt(pdpt_phys + HIGHER_HALF_START);

        for (0..512) |pdpt_idx| {
            const pdpt_entry = pdpt[pdpt_idx];
            if ((pdpt_entry & PAGE_PRESENT) == 0) continue;

            const pd_phys = pdpt_entry & paging_const.PTE_MASK;
            const pd: [*]volatile u64 = @ptrFromInt(pd_phys + HIGHER_HALF_START);

            for (0..512) |pd_idx| {
                const pd_entry = pd[pd_idx];
                if ((pd_entry & PAGE_PRESENT) == 0) continue;

                const pt_phys = pd_entry & paging_const.PTE_MASK;
                const pt: [*]volatile u64 = @ptrFromInt(pt_phys + HIGHER_HALF_START);

                // Free all physical pages in this page table
                for (0..512) |pt_idx| {
                    const pt_entry = pt[pt_idx];
                    if ((pt_entry & PAGE_PRESENT) == 0) continue;

                    const page_phys = pt_entry & paging_const.PTE_MASK;

                    // Compute virtual address from indices
                    const virt: u64 = (@as(u64, pml4_idx) << 39) |
                        (@as(u64, pdpt_idx) << 30) |
                        (@as(u64, pd_idx) << 21) |
                        (@as(u64, pt_idx) << 12);

                    // Only free if not a shared page
                    if (should_free_page(virt, page_phys)) {
                        pmm.free_page(page_phys);
                    }
                }

                // Free the PT page itself
                pmm.free_page(pt_phys);
            }

            // Free the PD page itself
            pmm.free_page(pd_phys);
        }

        // Free the PDPT page itself
        pmm.free_page(pdpt_phys);
    }

    // Free the PML4 page itself
    pmm.free_page(page_table_phys);
}
