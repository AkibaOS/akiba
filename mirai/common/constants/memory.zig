//! Memory Constants - Page sizes, address space layout, and page table definitions

// ============================================================================
// Page and Memory Block Sizes
// ============================================================================

/// Standard page size (4KB on x86-64)
pub const PAGE_SIZE: u64 = 4096;

/// Page offset mask (bits 0-11)
pub const PAGE_OFFSET_MASK: u64 = 0xFFF;

/// Page frame mask (clears offset bits)
pub const PAGE_FRAME_MASK: u64 = ~PAGE_OFFSET_MASK;

// ============================================================================
// Memory Address Space Layout
// ============================================================================

/// Higher-half Mirai (kernel) space start (canonical address boundary)
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

/// Mirai physical start address (loaded at 1MB)
pub const MIRAI_PHYSICAL_START: u64 = 0x100000;

/// Mirai physical end address
pub const MIRAI_PHYSICAL_END: u64 = 0x500000;

/// Virtual address where Mirai is mapped
pub const MIRAI_VIRTUAL_START: u64 = HIGHER_HALF_START + MIRAI_PHYSICAL_START;

/// External linker symbol marking the end of the Mirai binary
extern const _kernel_end: u8;

/// Dynamically calculate the physical address where Mirai binary ends
pub fn MIRAI_END() u64 {
    const link_addr = @intFromPtr(&_kernel_end);
    if (link_addr >= HIGHER_HALF_START) {
        return link_addr - HIGHER_HALF_START;
    } else {
        return link_addr;
    }
}

// ============================================================================
// Kata (Userspace) Address Space Layout
// ============================================================================

/// Kata virtual address start (first valid page after null page)
pub const KATA_SPACE_START: u64 = 0x1000;

/// Kata virtual address maximum (canonical address boundary)
pub const KATA_SPACE_END: u64 = 0x0000800000000000;

// ============================================================================
// Page Table Entry Flags
// ============================================================================

/// Page is present in memory
pub const PTE_PRESENT: u64 = 1 << 0;

/// Page is writable
pub const PTE_WRITABLE: u64 = 1 << 1;

/// Page is accessible from kata mode
pub const PTE_USER: u64 = 1 << 2;

/// Page has write-through caching
pub const PTE_WRITE_THROUGH: u64 = 1 << 3;

/// Page caching is disabled
pub const PTE_CACHE_DISABLE: u64 = 1 << 4;

/// Page has been accessed
pub const PTE_ACCESSED: u64 = 1 << 5;

/// Page has been written to
pub const PTE_DIRTY: u64 = 1 << 6;

/// Page is a huge page (2MB or 1GB)
pub const PTE_HUGE_PAGE: u64 = 1 << 7;

/// Page is global (not flushed on CR3 reload)
pub const PTE_GLOBAL: u64 = 1 << 8;

/// Execute disable bit
pub const PTE_NO_EXECUTE: u64 = 1 << 63;

// ============================================================================
// Page Table Structure
// ============================================================================

/// Number of entries in each page table level
pub const PAGE_TABLE_ENTRIES: usize = 512;

/// Shift for PML4 index (bits 39-47)
pub const PML4_SHIFT: u6 = 39;

/// Shift for PDPT index (bits 30-38)
pub const PDPT_SHIFT: u6 = 30;

/// Shift for PD index (bits 21-29)
pub const PD_SHIFT: u6 = 21;

/// Shift for PT index (bits 12-20)
pub const PT_SHIFT: u6 = 12;

/// Mask for table indices (9 bits = 512 entries)
pub const TABLE_INDEX_MASK: u64 = 0x1FF;

// ============================================================================
// Helper Functions
// ============================================================================

/// Align address down to page boundary
pub inline fn align_down(addr: u64) u64 {
    return addr & PAGE_FRAME_MASK;
}

/// Align address up to page boundary
pub inline fn align_up(addr: u64) u64 {
    return (addr + PAGE_SIZE - 1) & PAGE_FRAME_MASK;
}

/// Calculate number of pages needed for given size
pub inline fn pages_for_size(size: u64) u64 {
    return (size + PAGE_SIZE - 1) / PAGE_SIZE;
}

/// Check if address is page-aligned
pub inline fn is_page_aligned(addr: u64) bool {
    return (addr & PAGE_OFFSET_MASK) == 0;
}

/// Extract PML4 index from virtual address
pub inline fn pml4_index(vaddr: u64) u64 {
    return (vaddr >> PML4_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PDPT index from virtual address
pub inline fn pdpt_index(vaddr: u64) u64 {
    return (vaddr >> PDPT_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PD index from virtual address
pub inline fn pd_index(vaddr: u64) u64 {
    return (vaddr >> PD_SHIFT) & TABLE_INDEX_MASK;
}

/// Extract PT index from virtual address
pub inline fn pt_index(vaddr: u64) u64 {
    return (vaddr >> PT_SHIFT) & TABLE_INDEX_MASK;
}

/// Get physical address from higher-half virtual address
pub inline fn virt_to_phys(vaddr: u64) u64 {
    return vaddr - HIGHER_HALF_START;
}

/// Get higher-half virtual address from physical address
pub inline fn phys_to_virt(paddr: u64) u64 {
    return paddr + HIGHER_HALF_START;
}
